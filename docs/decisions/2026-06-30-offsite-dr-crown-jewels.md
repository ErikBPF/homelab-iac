# Off-premise DR anchor for tf state, sops, and Vault seal (voyager)

**Status:** Implemented (2026-06-30) — all four tiers (4a–4d) live; see §10.
**Date:** 2026-06-30.
**Audience:** Fleet maintainer (`desktop-nixos` + `homelab-iac`).
**Post-read action:** None — shipped. Kept as the design record.

## 1. Context

The fleet's backup story for its most critical *configuration* — OpenTofu
state, sops-encrypted secrets, and the sops age key — is mature **within one
building** and thin **outside it**.

Current tf-state mesh (`homelab-iac`, as-built in `docs/disaster-recovery.md`):

| Copy | Location | Failure domain |
|---|---|---|
| Authoritative | MinIO bucket `tofu-state` on **discovery** (sda2) | house |
| On-disk mirror | `discovery:/home/erik/tofu-state-export` (`mc mirror --watch`) | house |
| Off-host #1 | `orion:/home/erik/tofu-state-backup` (Syncthing, 30-day versioning) | house |
| Off-host #2 | `kepler:/home/erik/tofu-state-backup` (Syncthing, 30-day versioning) | house |
| Versioned snapshots | `discovery:/home/erik/vault/restic/tofu-state` (sdb) | house |
| Off-site restic | **SFTP → `kepler`** (`restic-offsite` user, daily 07:00) | **house** |

Every copy — including the one *named* "off-site" — sits in the same house on
discovery/orion/kepler. A fire, theft, flood, or lightning event on one power
feed loses the whole mesh at once. The name "off-site" today means "off the
authoritative disk," not "off the premises."

Two Oracle **Always-Free** hosts are now in flight (`homelab-iac/oracle/`,
`modules/hosts/{voyager,telstar}`):

- **voyager** — Always-Free x86 micro (1 GB). Already purpose-built as the
  fleet's **off-premise restic REST receiver**: `restic/rest-server
  --append-only --private-repos`, port 8000, tailnet-only, data under
  `/srv/backups/restic` (see `servarr/machines/voyager/offsite.yml`). This is
  the fleet's first host in a *different failure domain*.
- **telstar** — Always-Free A1 (2 OCPU / 12 GB), intended for **public-facing
  personal projects**. Out of scope here (see §8).

The real gap is stated bluntly in the DR doc:

> **The sops age key is the single point of total loss.** Everything else
> (`secrets.yaml`, every `.env.sops`, `UNIFI_STATE_PASSPHRASE`, restic
> passwords) is git-committed but age-encrypted → already off-site on GitHub,
> recoverable *iff the age key survives*.

Age-key backup today is a manual instruction ("copy to a password manager /
offline media"). It is not automated, so it drifts and is untested.

## 2. Goal

Give the crown-jewel config tier a true **off-premise** copy and remove the
age-key single-point-of-loss, using the Oracle host that already exists for
exactly this purpose — at **$0** and without widening any host's attack
surface.

Success = *from a laptop with tailscale + one memorized passphrase, anywhere in
the world, with the house gone,* you can: recover the age key → decrypt every
sops secret → restore tf state → redeploy the fleet.

Non-goals:

- Not active-active HA. "HA" here means **retrievability under disaster + no
  single point of loss**, not a clustered control plane. A homelab does not
  need two live UDMs.
- Not moving the authoritative tf-state backend off MinIO@discovery.
- Not backing up bulk restic data (media, container volumes) off-premise — the
  1 GB micro can't hold it and it wasn't selected in scope. Bulk stays on-prem.
- Not redesigning the Vault backup pipeline — this **extends** the off-site tier
  of the existing `2026-06-29-vault-backup-plan.md` RFC onto voyager, it does
  not replace it.

## 3. Scope (locked)

The off-premise tier protects three data classes:

1. **sops age key** — the root of trust; the one irreplaceable secret.
2. **All repo `.env.sops` + `secrets.yaml`** — a GitHub-independent encrypted
   copy (belt-and-suspenders: survives GitHub loss/lockout, not just fire).
3. **OpenBao/Vault seal material + latest raft snapshot** — folded into this
   anchor so there is one coherent off-premise runbook, coordinated with the
   Vault backup RFC.

Explicitly out: bulk restic repo data (media/volumes) — on-prem only.

## 4. Design

Four independent work items, orderable independently. All traffic is
**tailnet-only** — nothing new is exposed to the public internet.

### 4a. tf state → voyager (true off-premise, append-only)

The `services.resticTofuState.offsiteRepository` option
(`modules/services/restic-tofu-state.nix`) already exists; it just points at
kepler over SFTP today. Two ways to make it genuinely off-premise:

- **Option A (lower effort):** stand up the existing `restic-offsite-target`
  module on **voyager** (dedicated `restic-offsite` user + SFTP), and repoint
  `offsiteRepository` from `kepler` to `voyager`. Reuses the SFTP wiring
  verbatim. Loses append-only (SFTP user can delete).
- **Option B (recommended):** send tofu-state to voyager's **already-running
  append-only REST server** as a new private repo namespace
  (`rest:http://<user>:<pass>@voyager:8000/tofu-state`). Requires teaching
  `restic-tofu-state.nix` a REST target variant alongside the SFTP one.
  **Append-only means a compromised or buggy sender cannot prune/delete
  history** — strictly stronger than SFTP for a DR copy, and it reuses the
  receiver voyager already runs for kepler.

Recommendation: **B.** Keep the kepler SFTP copy too (cheap, on-prem, fast
restore) — voyager becomes the off-premise tier, kepler stays the warm tier.

Verify: `restic -r rest:.../tofu-state snapshots` from discovery lists a fresh
snapshot; dead-man's-switch textfile metric already alerts on staleness.

### 4b. sops age key → passphrase-age escrow (removes the SPOF)

Escrow the age key as a **self-decrypting-with-a-passphrase** blob:

```bash
age -p ~/.config/sops/age/keys.txt > keys.age   # scrypt recipient, no key file needed
# recover anywhere, offline:
age -d keys.age > keys.txt                       # only input: the memorized passphrase
```

`keys.age` is ciphertext sealed by a passphrase that lives **only in a password
manager + one offline copy (off-premise)** — never on any fleet host, never in
git. It is held in two private failure domains:

- a **password manager** entry (cold-reachable from a fresh laptop), **and**
- `voyager:~/escrow/age-key.age` (off-premise, tailnet/break-glass only).

Two readable copies in different failure domains, both useless without the
passphrase. This is the item that closes the "single point of total loss."

> **Post-grill correction (2026-06-30):** an initial version committed `keys.age`
> to `desktop-nixos` — which is **public** — making the sealed blob world-readable
> and offline-brute-forceable, secured only by passphrase entropy. That was
> wrong: the blob is now **gitignored** (`secrets/escrow/*.age`) and lives only
> in the two domains above. The git-history copy still exists; if the passphrase
> is not high-entropy, rotate the age key (see `reference/key-rotation.md`).

### 4c. Encrypted secrets → GitHub-independent copy on voyager

The `.env.sops` / `secrets.yaml` files are already off-site on GitHub. The only
gap they have is **GitHub availability** (account lockout, outage, repo loss).
Close it with a periodic tarball of all tracked `*.sops.*` / `secrets.yaml`
across the sister repos, pushed to voyager's REST server as its own repo
namespace (`.../sops-config`). These files are already age-encrypted, so the
copy is ciphertext-on-ciphertext — safe on voyager, still needs the age key
(→ 4b) to open.

Low effort; it's a small restic job on the workstation (or discovery) over the
same tailnet path. Recommendation: nice-to-have, land after 4a/4b.

### 4d. OpenBao/Vault seal + snapshot → extend the Vault backup RFC off-site

`2026-06-29-vault-backup-plan.md` already designs raft snapshot → restic
(off-site, apart from the unseal key) → dead-man's-switch. A recent commit
shipped OpenBao off-site backup liveness + on-fail Discord alert. The single
change here: make that RFC's **off-site restic tier target voyager** (append-only
REST, same receiver as 4a) instead of an on-prem peer, so Vault DR shares this
one off-premise anchor. The unseal key stays escrowed separately (same
passphrase-age pattern as 4b, **never** co-located with the snapshot). Defer to
the Vault RFC for the pipeline; this proposal only fixes its destination.

## 5. HA / retrievability model

The property we're buying is **geographic + provider diversity**, not uptime:

- voyager is on Oracle's São Paulo region — different power, different network,
  different physical site from the house. Reachable over the tailnet from any
  device that can run tailscale.
- Recovery path with the house destroyed and GitHub unavailable:
  1. laptop joins tailnet → reaches voyager;
  2. `age -d keys.age` with the memorized passphrase → age key back;
  3. sops decrypts `UNIFI_STATE_PASSPHRASE` + restic passwords;
  4. `restic -r rest:.../tofu-state restore latest` → tf state ciphertext;
  5. `terragrunt plan` no-diff proves passphrase + provider creds + state align;
  6. redeploy fleet from `desktop-nixos` git (mirror clone if GitHub is gone).

No step depends on any in-house host surviving. That's the HA claim.

## 6. Recovery drills (DR that isn't rehearsed is a guess)

Each item ships with a one-command drill, run once at landing and then
quarterly:

- **4a:** restore `cloudflare/dns/terraform.tfstate` from voyager into a scratch
  dir, point a throwaway checkout at it, confirm `plan` is no-diff.
- **4b:** on a clean machine (or container) with *only* the passphrase,
  `age -d keys.age` and confirm the recovered key decrypts a known secret.
- **4d:** restore the Vault raft snapshot into a mock OpenBao, unseal with the
  escrowed key, confirm a known path reads back (per the Vault RFC's drill).

## 7. Cost & free-tier guard

$0. voyager is Always-Free; tf-state + sops + a Vault snapshot are megabytes, far
under the 200 GB Always-Free block-volume allotment and the 1 GB micro's disk.
The `oci_budget_budget` "any-actual-spend" alert already guards against an
accidental PAYG charge (`oracle/modules/instance/budget.tf`).

## 8. Cross-repo coordination & ordering

- tf state and its DR doc are owned by **`homelab-iac`**; the restic backup
  *modules* and the voyager *host* are owned by **`desktop-nixos`**. Land the
  desktop-nixos module/host change first (it carries the receiver + sender
  wiring), then update `homelab-iac/docs/disaster-recovery.md`'s copy table to
  add the voyager off-premise row.
- Vault pieces (4d) land in the Vault backup RFC's implementation; this doc only
  redirects its off-site destination.
- **telstar is deliberately not the anchor.** It's public-facing; mixing the
  crown-jewel tier onto a host with public exposure widens its blast radius.
  voyager is tailnet-only and single-purpose. If bulk off-premise capacity is
  ever needed, telstar's A1 headroom is the place to revisit — as a *separate*
  decision, not this tier.

## 9. Decisions (locked 2026-06-30) & residual risks

Locked:

- **4a mechanism:** **append-only REST** (Option B). Sender cannot prune/delete
  history. Design decided; **deferred to land** after 4b.
- **4b escrow:** **scripted recipe** (`just escrow-age-key`) — automates
  generation + push; the passphrase is typed each run and never stored in the
  recipe. `keys.age` committed to **`desktop-nixos`** (where the recipe lives;
  the blob is passphrase-sealed ciphertext, safe in the main config repo) **and**
  pushed to voyager. **Land this first** — it closes the single point of loss.
- **Passphrase custody:** **password manager + one offline copy** (paper/USB in
  a safe). Survives password-manager loss; not memory-only.
- **Landing scope now:** **4b only**. 4a/4c/4d are designed above but not
  greenlit; natural sequence when picked up is 4b → 4a → 4c → 4d.

Residual risks:

- If the age key *and* the escrow passphrase are both lost, the tier is
  unrecoverable **by design** — that is the security property, not a bug. The
  password-manager + offline-copy custody is what keeps that from happening.
- **voyager as a lone off-premise host:** one Oracle instance = one failure
  domain outside the house. Losing voyager is not data loss (on-prem mesh
  survives); losing the house is not data loss (voyager survives). Losing both
  at once is the residual risk, mitigated by GitHub as the third location for
  4b/4c.
- **Scripted-recipe hazard:** the recipe must read the passphrase interactively
  (never from an env var / file / shell history). A leaked passphrase + a
  readable `keys.age` = full compromise of the root of trust.
- **Append-only maintenance (4a, when landed):** prune can't run from the
  sender; needs a rare privileged maintenance window or accept unbounded (tiny)
  growth.
- **voyager as a lone off-premise host:** one Oracle instance is one failure
  domain outside the house. Losing voyager is not data loss (the on-prem mesh
  survives); losing the *house* is not data loss (voyager survives). Losing
  both simultaneously is the residual risk, mitigated by GitHub as the third
  location for 4b/4c. Acceptable for a homelab.
- **Append-only retention:** append-only repos need periodic maintenance from a
  privileged path (prune can't run as the sender). Document a manual/rare prune
  window or accept unbounded (tiny) growth.

## 10. Implementation status (2026-06-30 — all shipped)

| Tier | What shipped | Where |
|---|---|---|
| **4b** age-key escrow | `just escrow-age-key` (passphrase-age blob, self-verifying) + `escrow-age-key-push` (→ voyager) + `escrow-age-key-verify` drill. `keys.age` is **gitignored** — lives on `voyager:~/escrow` + a password manager, **not** in this public repo (see post-grill note in §4b). | `justfile`, `secrets/escrow/` |
| **4a** tf state | `services.resticTofuState.restRepository` → voyager append-only REST `/discovery/tofu-state`, daily 07:30, no prune. Snapshot verified landing. | `modules/services/restic-tofu-state.nix`, `modules/hosts/discovery/default.nix` |
| **4c** encrypted-secrets copy | `just escrow-secrets` bundles every `ENC[`-verified sops file (this repo + homelab-iac + servarr) → `voyager:~/escrow/sops-config.tar.gz`. | `justfile` |
| **4d** Vault snapshot | `services.restic.backups.vault-rest` → voyager append-only REST `/discovery/openbao`, daily 03:40, no prune, liveness + Discord on-fail. | `modules/hosts/discovery/vault.nix` |

Voyager receiver: `restic/rest-server --append-only --private-repos`; a second
htpasswd user `discovery` (isolated to `/data/discovery/`) added alongside
`kepler` (servarr `machines/voyager/offsite.yml`). Credentials: `discovery`
REST password in servarr `.env.sops`; the credential-bearing repo URLs in
desktop-nixos `secrets.yaml` (`restic_tofu_rest_url`, `restic_vault_rest_url`),
passed via `repositoryFile` so they never enter the nix store.

**Gotcha (cost a redeploy):** restic REST with `--private-repos` returns **401**
(not 403) when the URL path does not start with the authenticated username — the
repo path must be `/<user>/<repo>` (e.g. `/discovery/tofu-state`).

Not covered (accepted): bulk restic data stays on-prem (1 GB micro); `4c` runs
from the workstation (only host with every repo) so it is periodic/opportunistic,
not a timer; append-only repos are never pruned (tiny growth accepted).

## 11. Post-grill hardening (2026-06-30)

An adversarial review surfaced holes; the confirmed ones were fixed:

- **`keys.age` was in a PUBLIC repo** (🔴) → removed from the tree, gitignored
  (`secrets/escrow/*.age`), lives only on voyager + a password manager. History
  still holds the old blob — rotate the age key if the passphrase is weak (§4b).
- **DR reachability was circular** (🟠) — voyager's tailnet REST/ssh are
  ACL-gated to existing admin devices, and the SSH key to break in lived on the
  (lost) laptop. Fix: `just escrow-ssh-key` seals the admin SSH key (password
  manager + voyager); recovery uses voyager's **public-IP** break-glass SSH, not
  the tailnet ACL.
- **4a (tofu-state off-premise) was unmonitored** (🟠) while 4d had liveness +
  on-fail → added the same `restic_tofu_state_rest_last_success_seconds` metric
  + Discord `onFailure` to `tofu-state-rest`.

Open follow-ups (accepted, not yet done): (a) **restore never drilled** — verify
a restic restore *from voyager* → decrypt → `terragrunt plan` no-diff; (b)
~~**voyager disk** — `/` is ~51% full and shared with kepler's append-only pushes
that never prune → add a disk-usage alert, a scheduled `restic check`, and a
documented prune window~~ **done 2026-07-01** — voyager node_exporter + Grafana
alerts, weekly `restic-check-voyager` on discovery, prune window in
[`reference/voyager-offsite-maintenance.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/voyager-offsite-maintenance.md);
(c) **escrow passphrase custody** — confirm the offline copy is off-premise.
