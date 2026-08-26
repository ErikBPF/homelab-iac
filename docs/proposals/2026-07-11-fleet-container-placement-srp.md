# Fleet container placement & SRP — one rule for "which runtime", plus separations

**Status:** Partially implemented. The 2026-08-26 first-wave Kubernetes cutover
established the current ownership boundary; the historical PocketID/NetBird
extraction sections remain retired and must not be implemented.

## 2026-08-26 implementation record

- `homelab-gitops` now owns the lab Kubernetes workload lifecycle and the
  Kubernetes-hosted home/platform services: Immich, Karakeep, Changedetection,
  Langfuse, monitoring, and Wazuh. Argo CD reports every application Healthy and
  Synced at `homelab-gitops` revision `5c9895ad66c3d19f4c7182966f385661cef9ccb1`.
- `servarr` retired the first-wave Compose definitions for Immich, Karakeep,
  Changedetection, and Langfuse. It remains the owner of household Compose
  workloads and their runtime lifecycle; “media-only” is a target boundary, not
  a completed-state claim.
- Native host Alloy telemetry is live for Orion and Kepler. The temporary
  Prometheus federation still carries application exporters that native host
  Alloy does not replace, so removing federation is not yet safe.
- Wazuh's Orion host-agent canary produced an attributed synthetic SSH alert on
  2026-08-26. The accepted seven-day observation gate ends on 2026-09-02; the
  Compose fallback must remain until that gate passes.
- Kepler's real offsite Restic push completed at Servarr revision
  `99e3a00544fa5e517980c7cfa06ab5494c49dbdb`; Prometheus observed a fresh
  `restic_kepler_offsite_last_success_seconds` sample.

This record supersedes the stale workload examples in the researched 2026-07-11
inventory below. The placement principles remain historical context; current
repository ownership is defined by `AGENTS.md` and `repos.json`.

> Scaffold for human judgment. The inventory below is **researched** (three
> read-only passes over `desktop-nixos/modules/` and `servarr/machines/`), cited to
> files. The *rule* and the *re-home* actions are proposals with **decision gates** —
> ruled by a human, phased, each independently reversible. This RFC changes **no
> repo-ownership SSOT** (the D1–D9 model stands); it only makes the *runtime
> mechanism* choice explicit and fixes the clear violations.

## 1. Motivation

The fleet runs containers **five different ways** with no written rule for which to
use. Placement is historical accident, and it shows:

- **One logical service, three placements.** `hermes-agent` is an enabled Docker
  **oci-container** (`hermes-oci.nix`), a superseded **systemd-nspawn** module still
  in-tree (`hermes-agent.nix`), and a retired **orion compose** stack (ghost comment
  in `orion/compose.nix`).
- **A fleet-wide identity service bundled into a VPN module.** PocketID (a
  general-purpose OIDC/SSO IdP) is defined inside `discovery-netbird-server` and
  gated on `services.netbirdServer.enable` — its lifecycle, image, secret, and
  `id.<zone>` ingress all owned by "the NetBird control plane".
- **A crown-jewel service on a bespoke third path.** Harbor is neither a
  `homelab.compose` stack nor an oci-container — it's its own systemd oneshot
  running a vendor-generated `docker-compose up`.
- **No boundary for new work.** When the next containerized service arrives, nothing
  says whether it's a servarr stack, a NixOS oci-container, or a k3s workload.

Goal: **a single placement decision rule**, a **fleet audit** against it, and the
**high-value SRP separations** it exposes — led by extracting PocketID into a
standalone fleet identity service (the [PocketID bring-up RFC](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-11-pocketid-idp-for-netbird.md)
consumer). Minimal churn: most services are already placed correctly; this names
*why* and fixes the handful that aren't.

## 2. Current state (researched inventory)

**Five mechanisms:**

| # | Mechanism | Where declared | Secret tier | Deploy | What runs there |
|---|-----------|----------------|-------------|--------|-----------------|
| M1 | **servarr compose stack** via NixOS `homelab.compose` | `servarr/machines/<host>/*.yml`; orchestrated by `modules/server/orchestration.nix` | sops `.env` (+ vault-agent `/run/vault-agent/<stack>.env` layered, Vault wins) | `pull-servarr` + `kick-stack` | Home workloads such as media, *arr, Plex, Jellyfin, Immich, Langfuse, Wazuh, Postgres/Redis/MinIO, SWAG, AdGuard, Cloudflared, LiteLLM, Vault, and Vaultwarden. |
| M2 | **NixOS `oci-containers`** | `modules/hosts/<host>/*.nix` | **sops-nix** → `/run/secrets` → docker `environmentFiles` | `switch-<host>` | discovery: `hermes-agent` (on), `netbird-*` (off); voyager: `netbird-relay` (off, rootless podman) |
| M3 | **Bespoke systemd-oneshot compose** | `modules/hosts/discovery/harbor.nix` | vault-agent `harbor.env` | `switch` (oneshot runs vendor compose) | Harbor registry + pull-through cache |
| M4 | **k3s microvms + Argo CD** | `modules/hosts/kepler/k3s-cluster.nix` (substrate) + `homelab-gitops` (workloads) | ESO → Vault@discovery | Argo sync | lab/prod-mimic k8s workloads (kepler only) |
| M5 | **VM / kernel isolation** | `haos.nix` (libvirt), `kepler/k3s-cluster.nix` (microvm.nix), `orion/gemini.nix` (nspawn) | n/a | `switch` | HAOS, k3s nodes, orion `gemini` dev sandbox |

**Secret-tier split (the load-bearing distinction):** M2 gets a single sops-nix
file the **root docker daemon** reads at container start. M1 gets a git-pulled,
sops-decrypted `.env` **plus** per-stack Vault-rendered env-files layered on top.
M4 gets ESO→Vault. So "where a service lives" and "how it gets secrets" are
coupled — a service needing **bootstrap-tier sops** secrets fits M2/M3; a service
needing **runtime-tier Vault** secrets fits M1/M4.

*Inventory sources: three read passes — fleet oci-container map, servarr compose
inventory (33 stacks), and the `homelab.compose`/secret-model deep read. Full
tables in the session recon; key file anchors cited inline below.*

## 3. The placement decision rule

**Default is M1 (servarr compose).** Escalate *only* when a test below trips.
Evaluate top-down; first match wins:

```
1. Lab / prod-mimic / ephemeral experiment?
      → M4  (homelab-gitops k3s + Argo; vcluster for throwaways)     [D1/D3]
2. Needs kernel/VM isolation (own kernel, device passthrough, untrusted)?
      → M5  (microvm.nix / libvirt / nspawn)
3. FLEET-TRUST SUBSTRATE — holds fleet-wide trust (identity/SSO, overlay
   control plane, registry signing) OR needs bootstrap-tier **sops** secrets
   OR must deploy ATOMICALLY WITH THE OS (version-pinned, in the switch)?
      → M2  (NixOS oci-container / native service, in desktop-nixos)
4. Otherwise — household/app/datastore/edge workload, runtime-tier secrets,
   git-pull cadence?
      → M1  (servarr compose stack)                                  [the bulk]
```

**Why the rule lands where it does, not "all substrate → M2":** edge proxy (SWAG),
DNS (AdGuard), and datastores (postgres/redis/minio) are *substrate* but their
secrets are runtime-tier and their **config co-lives with the apps** (SWAG
proxy-confs are per-app files in the servarr tree). Moving them to M2 buys nothing
and costs the app-config locality — so test 3 gates on **fleet-trust / sops-tier /
atomic-with-OS**, which they don't trip. PocketID, NetBird, and hermes **do** (see
audit). This keeps churn minimal.

**Three invariants (independent of the tree):**

- **I1 — one logical service ⇒ exactly one mechanism.** Retire the ghosts (hermes's
  dead nspawn module + orion-compose comment).
- **I2 — no *new* bespoke per-service orchestrator.** Harbor's oneshot (M3) is
  **grandfathered and documented**, not a pattern to copy; new substrate uses M2.
- **I3 — secret scope is per-service, not per-stack-bundle.** A stack's env must not
  carry another service's credentials (today `homepage` receives `*ARR_API_KEY` +
  `GRAFANA_ADMIN_*`; `discord.env` mixes a Scrutiny notify URL).

## 4. Fleet audit against the rule

Most services **pass** (correctly M1). The table lists only the **verdicts that
aren't a clean pass** — everything else stays put.

| Service | Today | Rule says | Action | Prio |
|---------|-------|-----------|--------|------|
| **PocketID** | M2, *inside* `netbird-server.nix` | M2, but its **own** identity concern | **Extract** to a standalone `identity`/`pocket-id` module (§5) | **P0** |
| NetBird control plane (mgmt/signal/dashboard/relay#1) | M2 | M2 ✓ | Keep; **remove PocketID** from it | P0 (with §5) |
| `hermes-agent` | M2 **+** dead nspawn **+** ghost compose | M2 | **I1 cleanup** — delete `hermes-agent.nix` (nspawn) + orion ghost | P1 |
| Harbor | M3 (bespoke oneshot) | M2-class substrate, but vendor-generated compose | **I2** — keep, **document** as the one sanctioned M3 | P1 (doc) |
| `discovery/infra.yml` (postgres+redis **+ Vault + Vaultwarden + minio-tfstate**) | M1, 4 concerns in one stack | M1, but SRP-split | **Split** → datastores / secrets(Vault) / vaultwarden / tfstate-store | P2 |
| `k8s-apiserver` nginx shim | M1, inside `networking.yml` (SWAG+DNS) | M1, wrong stack | **Move** out of the edge stack (own/k8s concern) | P2 |
| Cross-service secret bundles (`homepage`←arr+grafana; `discord.env`←scrutiny) | per-stack vault-agent render | I3 | **Re-scope** vault-agent renders per-service | P2 |
| `servarr-pull` (git reset **+** `.env` decrypt **+** `homelab-net` create) | one oneshot, 3 jobs | SRP-split | **Split**; make `homelab-net` a first-class unit ordered before **M2** too (fixes the [bring-up RFC](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-11-pocketid-idp-for-netbird.md) §3a race) | P2 |
| in-container **Vault** (`infra.yml`) | M1 | M2-class (secrets substrate) but **high blast radius** | **Defer** — own RFC; do not move casually | non-goal here |
| SWAG, cloudflared, AdGuard, postgres/redis/minio | M1 | M1 ✓ (test 3 not tripped) | Keep — app-config locality wins | — |
| kepler compose (12), orion/voyager stacks | M1 | M1 ✓ | Keep | — |

## 5. Flagship separation — PocketID → standalone fleet identity

**The ask (this session's decision): PocketID is fleet SSO, not NetBird's sidecar.**
It can front Grafana, Harbor, Vaultwarden, dockhand, any SWAG app via OIDC — NetBird
is just **one** client. Bundling it in the VPN module couples a fleet-trust service
to `netbird` lifecycle, tags, secrets, and ingress. Extract it:

- **New module** `modules/hosts/discovery/pocket-id.nix` →
  `flake.modules.nixos.discovery-pocket-id`, option `services.pocketId.enable`
  (default false). Owns the `pocket-id` oci-container (M2), the `ENCRYPTION_KEY`
  secret, the `id.<zone>` ingress, and the SQLite data dir. Container renamed
  `netbird-pocketid` → `pocket-id`.
- **Secrets rename** `netbird/pocketid_jwt_key` → **`identity/pocket-id_encryption_key`**
  (also fixes the misleading "jwt" label, §2 of the bring-up RFC). Zero migration —
  the secret isn't minted yet.
- **NetBird module keeps only its own OIDC *client* config** — issuer/client-id/
  audience pointing at `https://id.<zone>`, i.e. NetBird becomes a **consumer** of
  the identity module, exactly like any future OIDC app.
- **This supersedes the `idpOnly` mode.** The `idpOnly` flag existed only because
  PocketID was welded to NetBird's 4-secret activation (bring-up RFC §3). Once
  PocketID is its own module declaring **only** its own secret, "bring up just the
  IdP" is simply *enable the identity module, leave netbird off* — no special mode.
  **`idpOnly` is deleted**; the bring-up RFC's Phase-S/bootstrap steps retarget the
  new module (same runbook, cleaner structure).
- **Ingress** `id.<zone>` proxy-conf stays servarr-owned (SWAG is M1) — unchanged
  from the bring-up RFC §4.

Consequence: the sops-activation landmine that motivated `idpOnly` **dissolves** —
the identity module and the netbird module each declare only their own secrets, so
neither can fail the other's activation.

## 6. Secondary separations (ranked, each a decision gate)

- **P1 — hermes I1 cleanup.** Delete the superseded `hermes-agent.nix` (nspawn) and
  the orion ghost. One service, one mechanism. Low risk (dead code).
- **P1 — Harbor I2 doc.** Add a short reference note: Harbor is the *one* sanctioned
  M3 (vendor generates its own compose; wrapping it in M1/M2 is more fragile than
  grandfathering it). Not a template for new work.
- **P2 — split `infra.yml`.** Four concerns → separate stacks
  (`datastores` | `secrets` | `vaultwarden` | `tfstate`), still M1/servarr. Improves
  blast-radius isolation (a Vaultwarden bump can't disturb postgres) and lets
  `vaultEnvStacks` scope secrets tighter. Medium risk (restart choreography).
- **P2 — `k8s-apiserver` shim** out of `networking.yml` into its own file/concern.
  Small, mechanical.
- **P2 — `homelab-net` as a first-class unit.** Extract network-create from
  `servarr-pull` into a dedicated oneshot both M1 stacks **and** M2 oci-containers
  order `after` — closes the latent boot race the bring-up RFC §3a flagged for
  hermes/netbird.
- **P3 — secret-schema per-service (I3).** Re-scope the monolithic vault-agent
  `.hcl` so each service's render carries only its own keys; kill the cross-service
  bleed. This is a **secret-schema** refactor riding alongside container placement —
  candidate to **spin into its own RFC** if it grows (it touches every stack's env).

## 7. Non-goals / explicitly not touched

- **Repo-ownership SSOT (D1–D9) is unchanged.** desktop-nixos still owns substrate,
  servarr owns compose workloads, homelab-gitops owns lab. This RFC picks the
  *runtime mechanism within* that model, not who owns what.
- **No wholesale migration of M1 substrate to M2.** SWAG/Vault/postgres/AdGuard stay
  compose — test 3 doesn't trip them and app-config locality is real.
- **In-container Vault relocation is deferred** to its own RFC (high blast radius;
  it's the runtime-secret SSOT).
- **No autonomous deploy.** Every move is human-gated; `just dry <host>` + eval gate
  each; crown-jewel discovery changes follow the switch-discovery human gate.

## 8. Decision gates

| # | Gate | Options | Recommendation |
|---|------|---------|----------------|
| **D-1** | Adopt the §3 rule as the fleet standard? | (a) yes, record in `dendritic-contract.md` / CLAUDE.md; (b) keep ad-hoc | **(a)** — the rule is what makes every later move non-arbitrary. |
| **D-2** | PocketID extraction (§5) | (a) standalone `identity` module now (**ruled this session**); (b) leave in netbird | **(a)** — already decided; §5 is the how. |
| **D-3** | Identity module name/scope | (a) `pocket-id` (service-named, minimal); (b) `identity` (role-named, room for more IdP infra) | **(a) `pocket-id`** now — one service; rename to `identity` only if a second identity component appears (YAGNI). |
| **D-4** | `idpOnly` mode | (a) delete (extraction makes it moot); (b) keep as belt-and-suspenders | **(a) delete** — the module split is the real fix; two mechanisms for one need is the smell. |
| **D-5** | Harbor M3 | (a) grandfather + document (I2); (b) rework into M1/M2 | **(a)** — vendor-generated compose; reworking is fragile for no SRP gain. |
| **D-6** | `infra.yml` split (P2) | (a) split 4 ways; (b) split out only Vaultwarden+Vault (identity/secrets) from datastores; (c) leave | **(b)** — biggest SRP win (secrets/identity off the datastore blast radius) at half the churn; full 4-way split later if wanted. |
| **D-7** | Secret-schema per-service (P3, I3) | (a) fold into this RFC; (b) spin its own RFC | **(b)** — it touches every stack's env; keep this RFC container-placement-focused. |
| **D-8** | Rollout order | see §9 | Ship P0 first, prove it, then P1/P2 opportunistically. |

## 9. Phasing

1. **P0 — PocketID extraction (§5)** — new `pocket-id` module, secrets rename,
   NetBird demoted to client, `idpOnly` deleted. Retarget the bring-up RFC runbook.
   Verify: `just lint && fmt-check && structure-check`; **`just dry discovery` clean
   no-op** (both modules default-off). This unblocks the bring-up RFC cleanly.
2. **P1 — I1/I2 hygiene** — delete hermes nspawn ghost; document Harbor as sanctioned
   M3; record the §3 rule in the dendritic contract.
3. **P2 — targeted separations** — `homelab-net` first-class unit (closes the M2 boot
   race); `infra.yml` secrets/identity split (D-6); `k8s-apiserver` shim relocate.
   Each: eval + `just dry` + human switch, one host at a time.
4. **P3 (own RFC)** — secret-schema per-service (I3), if pursued.

Each phase is independently reversible and leaves `just dry` a clean no-op until a
human enables the touched piece.

---

*Cross-refs:* [`implemented/2026-06-29-repo-ssot-srp.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-repo-ssot-srp.md)
(D1–D9 repo-ownership model this refines, not changes),
[`reference/dendritic-contract.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/dendritic-contract.md)
(where the §3 rule would be recorded).
