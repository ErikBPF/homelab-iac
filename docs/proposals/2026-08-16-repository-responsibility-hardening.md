# Repository responsibility hardening — publish, pin, and delegate

**Status:** In progress — P0–P2, the exact Servarr Discovery canary, and Telstar
lock recovery are complete; Servarr publication and credential recovery remain
**Date:** 2026-08-16
**Last reviewed:** 2026-08-16
**Owners:** `homelab` (cross-repository gates), each producer repository (its
implementation), and each consumer repository (its pin and deployment)

## Goal

Enforce the repository boundaries already locked in
[`2026-06-29-repo-ssot-srp.md`](../decisions/2026-06-29-repo-ssot-srp.md):

- producers publish immutable artifacts or exact revisions;
- consumers pin them instead of executing sibling working trees;
- coordination commands delegate component lifecycle;
- runtime Vault access remains the only live cross-repository dependency.

This proposal fixes boundary violations. It does not reopen repository
placement, secret-platform, or workload-runtime decisions.

## Verified violations

| Finding | Source | Failure mode |
|---|---|---|
| Unprotected GitOps deployment branch | `homelab-iac/github/repos/terragrunt.hcl`; `homelab-gitops/bootstrap/root-app.yaml` | Argo tracks `main` with automated prune/self-heal while the private repository has `protect_main = false`; a direct push can deploy cluster-wide. |
| Unpinned state-changing IaC execution | `desktop-nixos/modules/hosts/discovery/telstar-capture.nix` | The service pulls `homelab-iac/main`, ignores pull failure, then executes the checkout with infrastructure authority. |
| Unpinned scheduled drift implementation | `desktop-nixos/modules/services/homelab-iac-drift.nix` | A timer pulls and executes the current IaC branch with runtime credentials. |
| Live Servarr script execution from NixOS | `desktop-nixos/modules/hosts/discovery/harbor.nix` | The unit executes scripts from a mutable Servarr checkout. |
| Default branch-head workload activation | `desktop-nixos/modules/server/orchestration.nix` | Exact-revision activation exists, but the default path fetches and resets to a mutable branch head. |
| Stale vendored fleet artifacts | `desktop-nixos/fleet.json`; vendored copies in `homelab-iac` and `servarr` | Both consumers still record Voyager at `147.15.7.254`; the publisher records `163.176.78.19`, and `just fleet-drift` fails. |
| Stale boundary documentation | `homelab-iac/README.md`; `homelab-gitops/README.md` | Home Assistant addressing/artifact instructions and OpenBao ownership no longer match the owning repositories. |
| Ambiguous secret authority label | Servarr secret registry and adoption records | `desktop-nixos:vault` conflates Vault value authority with host delivery ownership. |

The Graphify cache supported the existing publish-and-pin and one-owner rules,
but it predates this proposal; every finding above was verified in source.

## Enforced rules

### R1 — coordinate, do not duplicate

`homelab` owns inventory, cross-repository decisions, audits, artifact
synchronization, and delivery order. Root commands may call component commands,
but must not implement Terraform apply, Compose recreation, Argo sync, package
publication, or device deployment.

### R2 — separate scheduling from implementation

`desktop-nixos` may own when and where a job runs: systemd units and timers,
users, sandboxing, credential projection, resource limits, and health checks.
The domain repository owns the command. The host pins an immutable artifact or
exact revision; it does not `git pull` a branch at runtime.

### R3 — publish, then pin

The producer lands and validates first. The consumer then pins an exact version,
digest, commit, or vendored artifact. A Git checkout is acceptable only when the
commit is recorded and activation fails closed if it is unavailable.

Argo branch tracking is allowed only when the branch is protected or automated
prune/self-heal is disabled. An unprotected mutable branch with automated
pruning is never allowed.

### R4 — name secret responsibilities precisely

| Concern | Owner |
|---|---|
| Runtime value | Vault/OpenBao |
| Root-of-trust, bootstrap, host/build secret | Sops in `desktop-nixos` |
| Host projection and file permissions | `desktop-nixos` |
| Variable schema and workload use | Workload repository |
| External API resource | `homelab-iac` |

For the current Servarr schema, document `desktop-nixos:vault` as “Vault value,
delivered by `desktop-nixos`.” Do not redesign the registry solely to rename the
label.

## Delivery plan

### P0 — contain GitOps auto-deployment

Protected branches are unavailable for a private repository on the current
GitHub Free plan. Remove `syncPolicy.automated` from
`homelab-gitops/bootstrap/root-app.yaml`. Keep root and child Applications on
manual sync, and pass the reviewed merge commit SHA explicitly when syncing.
This is the durable free-plan mode; no new publication mechanism is required.

Restore automated prune/self-heal only if `main` gains branch protection. Do
not treat pinning only the root Application as sufficient: child Applications
also track `main`.

**Gate:** rendered manifests pass; the live root Application has no automated
sync policy; root and child syncs use the reviewed commit SHA; rollback to the
prior Git revision is documented and tested.

### P1 — correct boundary documentation

1. Confirm the publisher's Voyager address, then deliberately refresh the
   `homelab-iac` and Servarr `fleet.json` pins until `just fleet-drift` passes.
2. Fix the Home Assistant address and vendored `fleet.json` workflow in the
   `homelab-iac` README.
3. Fix OpenBao host/value/projection language in the `homelab-gitops` README.
4. Clarify the Servarr registry's compound authority label using R4; change no
   secret value or delivery path.

**Gate:** component documentation agrees with `repos.json`, `fleet.json`, and
the runtime-secret boundary; existing registry validation still passes.

### P2 — prove pinning on IaC drift

Use `homelab-iac-drift` as the read-only canary.

1. Pin the existing `homelab-iac` command at an exact Git revision in
   `desktop-nixos`; add packaging only if direct revision pinning cannot satisfy
   the service sandbox or runtime inputs.
2. Keep only scheduling, sandboxing, credential projection, and reporting in
   `desktop-nixos`.
3. Prove the pinned source is byte-identical to the Git archive for the recorded
   commit, then run one read-only plan. Live plans are observational evidence,
   not stable equality fixtures: provider state can change between executions.
4. Remove the runtime `git pull` only after source identity, the successful
   pinned plan, and emergency pin-bump procedures are recorded.

**Gate:** the service executes the recorded revision with no sibling checkout or
runtime source fetch; the Git archive, locked Nix input, and deployed store path
have the same source hash; and the pinned read-only plan completes.

### P3 — migrate remaining live-checkout execution

Land each slice separately after P2:

- **Telstar capture:** `homelab-iac` owns the retry command and Terraform inputs;
  `desktop-nixos` schedules a pinned revision. Refresh failure must fail closed.
- **Harbor:** Servarr owns setup and proxy-cache behavior; NixOS consumes a
  pinned script artifact or Servarr-owned entrypoint instead of
  `/home/erik/servarr` source.
- **Servarr activation:** use the existing exact-revision path for production.
  Feature-branch activation remains temporary and operator-gated.
- **Compose operations:** fleet wrappers retain host selection, transport, and
  post-deploy health checks; Servarr owns pull/render/recreate semantics.

For each slice: land producer → identify immutable revision → bump consumer →
deploy → prove health and rollback → remove the mutable path.

## Implementation snapshot

| Phase | Source state | Remaining gate |
|---|---|---|
| P0 | All 13 live Applications are manual. The Airflow repository URL now uses GitHub SSH on port 443, matching the other Applications. | After Harbor recovery, sync only Airflow at reviewed GitOps merge `d736a9dfbcc58931881d0b636741f4fdb749efad`. |
| P1 | Vendored fleet snapshots, ownership docs, and the Servarr authority-label explanation are landed and validated. | Retain fleet and registry drift gates. |
| P2 | Complete on Discovery. Drift runs from exact IaC revision `5de040bd…`; its Git archive, locked Nix input, and deployed store path share NAR hash `sha256-FRKTI+4TLDkPrvBEkshA1L0500V4qTYv+/v4QXnSyUY=`. The read-only canary completed with drift exit `2` and systemd result `success`. | Retain the pin/hash/invocation evidence and bump leaf-first for producer changes. |
| P3 | Exact Servarr activation is proven on Discovery at `8307056b…`. The v2 pin, health checks, rollback to `ecae553…`, and repin passed without container recreation. | Publish Servarr scripts through an explicitly authorized CI-fetchable immutable channel, then pin Harbor/Kindle callers to it. |

## Routed out of scope

- Fleet upgrade, network security,
  [fleet alerting](2026-08-28-fleet-alerting-reliability-and-response.md), and
  stateful migration continue under their existing proposals.
- Component-local dead-code and test cleanup belongs in that component's issue
  or change, not this cross-repository hardening proposal.
- Campaign tooling remains governed by its owning proposal's evidence and
  retirement gate; this proposal neither inventories nor estimates deletions.

## Verification

### Coordination

- `just audit`
- `just docs-check`
- `just fleet-drift`
- `docs/proposal-index.md` matches this proposal's status, risk, next gate, and
  file coverage

### Acceptance

1. No privileged or scheduled service pulls a mutable sibling branch and then
   executes it with infrastructure or workload authority.
2. GitOps automated prune/self-heal never targets an unprotected mutable branch.
3. Host schedulers consume producer-owned immutable implementations.
4. Production Servarr activation records an exact commit and fails closed.
5. Root coordination commands delegate component deployment.

Each component uses its existing format, test, render/build, deployment, health,
and rollback gates. IaC apply remains human-approved.

## Implementation record — 2026-08-16

- `homelab-gitops` PRs
  [#39](https://github.com/ErikBPF/homelab-gitops/pull/39) and
  [#40](https://github.com/ErikBPF/homelab-gitops/pull/40) merged. All 13 live
  Applications are manual; root reconciled commit
  `4d5496c9bb6fa321d3361103aea9e8f40d88474c` before automation was removed.
  Airflow exists as a manual, unsynced Application.
- `homelab-iac` PRs
  [#64](https://github.com/ErikBPF/homelab-iac/pull/64) and
  [#65](https://github.com/ErikBPF/homelab-iac/pull/65) merged the ESO contract,
  guarded Telstar lock recovery, boundary docs, and refreshed fleet pin.
- `desktop-nixos` PR
  [#187](https://github.com/ErikBPF/desktop-nixos/pull/187) pins IaC merge
  `f1c4441bce15c58f175851e8f20544d0881215a9` and removes runtime Git pulls.
  Merge `6d48236d0473b1554516dd77822949bc582e2f8f` deployed to Discovery with
  deploy-rs confirmation.
- Servarr PR [#240](https://github.com/ErikBPF/servarr/pull/240) merged the
  pull-only Harbor robot provisioner, fleet pin, and Vault authority wording.
  Airflow's ten existing runtime values were copied to `secret/lab/airflow`
  without printing values or changing Kubernetes resources.
- Robot creation remains blocked: the sanctioned Vault
  `HARBOR_ADMIN_PASSWORD` receives HTTP 401 from live Harbor. No admin reset,
  project-public fallback, or over-privileged robot reuse was attempted.
- `homelab-iac` PR
  [#66](https://github.com/ErikBPF/homelab-iac/pull/66) merged as
  `608770d1fffd921ca35398d07a66d5f3193df831`. Scheduled drift no longer
  refreshes a Git checkout; Telstar retry handling fails closed and cleans up
  decrypted temporary files.
- Servarr PR [#241](https://github.com/ErikBPF/servarr/pull/241) merged as
  `8307056b8e5943d517672deba28fe6d254ccdf48`. Harbor setup/proxy scripts accept
  an explicit runtime directory, and generated registry artifacts were updated
  without including unrelated AI-model work.
- `homelab-gitops` PR
  [#41](https://github.com/ErikBPF/homelab-gitops/pull/41) merged as
  `d736a9dfbcc58931881d0b636741f4fdb749efad`, correcting Airflow's non-canonical
  port-22 repository URL. This supersedes the earlier Airflow sync revision.
- `desktop-nixos` PR
  [#188](https://github.com/ErikBPF/desktop-nixos/pull/188) merged as
  `a8e87f1344614907df9c80fcccf289b4fc7cdd32`. It adds machine-bound v2 pins,
  rejects v1/v2 overlap, routes operator and Kindle activation through the
  shared lock, and pins the merged IaC producer. Full flake evaluation and 134
  focused tests pass.
- `desktop-nixos` PRs
  [#189](https://github.com/ErikBPF/desktop-nixos/pull/189),
  [#190](https://github.com/ErikBPF/desktop-nixos/pull/190), and
  [#191](https://github.com/ErikBPF/desktop-nixos/pull/191) merged as
  `2bd070aba59a62778a6b2a91c87e12a911abfc7d`,
  `1c9281b6bd9ee1e7f3a054c1bf131545cce49f32`, and
  `9a4b599c65b746440ce77ba50e22b1bdd59a628f`. They provide Git for
  Terragrunt repository discovery, initialize metadata in the archive copy,
  and pin the serialized producer revision.
- `homelab-iac` PR [#67](https://github.com/ErikBPF/homelab-iac/pull/67)
  merged as `5de040bd3999fb16f6f14f81ab857fcc1b29f46b`, serializing
  `terragrunt run --all` against the shared provider cache. The focused Bats
  suite passes; the full suite has 49 passes and only its existing intentional
  LiteLLM-provider red test.
- Discovery deployed desktop merge `9a4b599c…`. Drift invocation
  `f2cce2b006ef4e92b55e342888bfa377` completed read-only with exit `2` and
  systemd result `success`. The exact Git archive, consumer lock, and deployed
  Nix store source all hash to
  `sha256-FRKTI+4TLDkPrvBEkshA1L0500V4qTYv+/v4QXnSyUY=`.
- Discovery's v2 Servarr pin now records `8307056b8e5943d517672deba28fe6d254ccdf48`.
  Pin verification, `servarr-pull`, Harbor, Kindle health, rollback to
  `ecae553…`, and repin passed without recreating containers.
- `desktop-nixos` PRs
  [#192](https://github.com/ErikBPF/desktop-nixos/pull/192),
  [#195](https://github.com/ErikBPF/desktop-nixos/pull/195), and
  [#196](https://github.com/ErikBPF/desktop-nixos/pull/196) merged as
  `190179fd367028742c2938efb24c79f09c01144d`,
  `f520562c2c5a18484c9ff449138bf593720fe4ec`, and
  `dfc394c582d8c28e79f282c9c06d33878a1aca49`. They invoke archive-carried
  helpers through Bash and pin both Telstar recovery fixes leaf-first.
- `homelab-iac` PRs
  [#68](https://github.com/ErikBPF/homelab-iac/pull/68) and
  [#69](https://github.com/ErikBPF/homelab-iac/pull/69) merged as
  `4688ca36df81c138e68269ac6962e50406fbb6e9` and
  `7f9968feb662c164891eded784370be1effb2fdc`. Recovery now supplies the required
  public key and parses Terragrunt-prefixed lock age metadata.
- After all three encrypted state copies matched SHA-256 and no active Telstar
  writer existed, stale lock `95a806a3-2c59-ab68-20e0-821a8534056a` was
  force-unlocked through the exact guarded recipe. Discovery deployed
  `dfc394c5…`; retry invocation `9c69bea72ed14185aeeb409e92ab839f` reached
  Oracle, observed `Out of host capacity`, and resumed its 60-second loop.

## Implementation collision audit

| Collision | Resolution |
|---|---|
| The Servarr repository is private while `desktop-nixos` CI has no sanctioned cross-repository read credential. A direct `github:ErikBPF/servarr/<sha>` input returns 404 and cannot be the P3 contract. | Do not add the input or hidden build credential. Publish the required producer files as one immutable, digest-pinned artifact through an approved CI-fetchable channel, then consume that artifact. |
| The proposed Servarr and desktop changes shared dirty worktrees with AI-model, Gemini, Endeavour, overlay, lock-file, alert, and Tailscale work. | Leaves and consumer were rebuilt from current `main`; unrelated working-tree changes remain untouched. |
| Airflow alone used GitHub SSH port 22, so the reviewed GitOps SHA still left repository access vulnerable to networks that block that port. | Canonicalize it to `ssh://git@ssh.github.com:443/...`; use the new GitOps merge for the eventual manual sync. |
| A v1 exact pin and v2 machine pin cannot safely share `.deploy-commit`. | Both writers reject the other version before mutation. Live Discovery inventory found no pin, so no migration is currently required. |
| Terragrunt's `get_repo_root()` still invokes Git even when source delivery no longer uses Git. | Keep `git` as a runtime input; this is command compatibility, not a mutable source fetch. |
| GitHub archive inputs omit `.git`, while Terragrunt requires repository metadata. | Initialize a local empty repository in the copied state directory. No remote or sibling checkout is read. |
| Parallel `tofu init` processes sharing one plugin cache stalled on fresh source. | Serialize the producer's existing `terragrunt run --all` with `--parallelism 1`; do not add another cache or lock layer. |
| Normalized plans from separate times differed because live provider state changed and producer summaries were bounded. | Use immutable source identity as the equivalence gate and retain one successful pinned read-only invocation. Do not treat live plan text as a deterministic fixture. |
| The Nix archive copy is mode-normalized, so the recovery helper was not executable when the consumer invoked it directly. | Invoke the producer helper through Bash; do not add a second copied script or runtime chmod. |
| Telstar lock validation evaluated Terraform inputs before backend inspection and lacked `OCI_SSH_PUBKEY_FILE`. | Give recovery the retry command's existing public-key default so validation reaches the exact remote lock. |
| Terragrunt prefixes lock metadata, so a column-anchored `Created:` parser rejected the confirmed lock silently. | Parse the timestamp after `Created:` regardless of prefix while retaining UUID, path, writer, and minimum-age guards. |

## Risks

| Risk | Mitigation |
|---|---|
| Pinning delays an urgent fix | Publish or select a new revision and use the recorded emergency pin bump; never fall back to a mutable branch. |
| Delivery migration changes behavior | First run the existing command at the same revision and compare outputs before removing the legacy path. |
| Manual Argo sync leaves drift unreconciled | Keep containment short, monitor sync status, and land one durable remedy before restoring automation. |
| Secret metadata cleanup moves values | Change documentation only in P1; never print, copy, or rotate values. |
| Private source pin fails in public CI | Publish one immutable artifact; do not depend on sibling paths or implicit developer credentials. |
| Dirty topic branches mix unrelated delivery | Land clean changes from current `main` and stage only named files. |
| An active v1 pin blocks v2 activation | Inventory before rollout; writers fail closed rather than replacing the other envelope. |

## Non-goals

- merging repositories or moving workloads between home and lab;
- replacing Vault, Sops, Argo CD, Terraform/OpenTofu, NixOS, or Compose;
- inventing a shared deployment framework or new package pipeline;
- executing adjacent security, fleet, observability, or stateful plans;
- deleting campaign tooling.

## Next gate

1. Under an explicitly approved Harbor recovery or rotation procedure,
   reconcile the live admin credential, create the pull-only Airflow robot, and
   sync only Airflow at GitOps commit
   `d736a9dfbcc58931881d0b636741f4fdb749efad`. Do not widen `library`, reuse a
   privileged robot, or infer permission to reset credentials.
2. Select and authorize one CI-fetchable immutable publication channel for the
   private Servarr producer files. Publish once, record the digest, and pin
   Harbor setup, proxy-cache, `mirror-kindle`, and the Kindle agent to that same
   artifact. Do not add a private Git input without an explicit credential and
   rotation design.

## References

- [`../decisions/2026-06-29-repo-ssot-srp.md`](../decisions/2026-06-29-repo-ssot-srp.md)
- [`2026-07-12-fleet-upgrade-hardening.md`](2026-07-12-fleet-upgrade-hardening.md)
- [`2026-07-13-stateful-stack-release-hardening.md`](2026-07-13-stateful-stack-release-hardening.md)
- [`2026-07-25-runtime-security-monitoring.md`](2026-07-25-runtime-security-monitoring.md)
- [`2026-08-01-network-router-security-segmentation.md`](2026-08-01-network-router-security-segmentation.md)
- [`2026-08-14-alert-reliability-improvements.md`](2026-08-14-alert-reliability-improvements.md)
- [`../../repos.json`](../../repos.json)
