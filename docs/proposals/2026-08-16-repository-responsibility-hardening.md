# Repository responsibility hardening — publish, pin, and delegate

**Status:** In progress — GitOps containment, boundary docs, and pinned
IaC/Telstar execution deployed; Harbor and Servarr activation slices remain
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
3. Run the legacy checkout and pinned command back-to-back at the same commit;
   compare normalized plans.
4. Remove the runtime `git pull` only after equivalence and emergency pin-bump
   procedures are recorded.

**Gate:** the service executes the recorded revision with no sibling checkout or
runtime source fetch, and two equivalent plan paths are retained as evidence.

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
| P0 | GitOps root and child Applications are manual; the sync wrapper requires an exact reviewed revision; tests and rollback documentation cover the 13-Application tree. | Verify the live root has no automated policy and exercise reviewed-SHA sync/rollback. |
| P1 | Both vendored fleet snapshots match `desktop-nixos`; Home Assistant/OpenBao ownership docs and the Servarr authority-label explanation are corrected. | Land the final IaC fleet refresh and retain the passing drift/registry checks. |
| P2 | `desktop-nixos` runs drift detection from the exact `homelab-iac` flake input in a private state directory; producer-side runtime refresh removal is prepared. | Publish the producer change, bump the pin, compare normalized plans, deploy, and retain evidence. |
| P3 | Telstar uses the same pinned input and its producer fail-closed change is prepared; Servarr has a minimal Harbor runtime-directory boundary; generic machine-bound v2 exact pins are implemented and accepted fail-closed. | Publish leaf changes, bump the Telstar pin, pin Harbor/Kindle consumers, migrate each production host, then remove mutable branch activation. |

## Routed out of scope

- Fleet upgrade, network security, alert reliability, runtime security, and
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

## Risks

| Risk | Mitigation |
|---|---|
| Pinning delays an urgent fix | Publish or select a new revision and use the recorded emergency pin bump; never fall back to a mutable branch. |
| Delivery migration changes behavior | First run the existing command at the same revision and compare outputs before removing the legacy path. |
| Manual Argo sync leaves drift unreconciled | Keep containment short, monitor sync status, and land one durable remedy before restoring automation. |
| Secret metadata cleanup moves values | Change documentation only in P1; never print, copy, or rotate values. |

## Non-goals

- merging repositories or moving workloads between home and lab;
- replacing Vault, Sops, Argo CD, Terraform/OpenTofu, NixOS, or Compose;
- inventing a shared deployment framework or new package pipeline;
- executing adjacent security, fleet, observability, or stateful plans;
- deleting campaign tooling.

## Next gate

Reconcile Harbor's live admin credential with its Vault value under an approved
rotation/recovery procedure, create the pull-only Airflow robot, then sync only
Airflow at GitOps commit `4d5496c9bb6fa321d3361103aea9e8f40d88474c`.
Separately compare one pinned IaC drift plan with its legacy baseline before
closing P2. Telstar force-unlock remains an explicit destructive gate.

## References

- [`../decisions/2026-06-29-repo-ssot-srp.md`](../decisions/2026-06-29-repo-ssot-srp.md)
- [`2026-07-12-fleet-upgrade-hardening.md`](2026-07-12-fleet-upgrade-hardening.md)
- [`2026-07-13-stateful-stack-release-hardening.md`](2026-07-13-stateful-stack-release-hardening.md)
- [`2026-07-25-runtime-security-monitoring.md`](2026-07-25-runtime-security-monitoring.md)
- [`2026-08-01-network-router-security-segmentation.md`](2026-08-01-network-router-security-segmentation.md)
- [`2026-08-14-alert-reliability-improvements.md`](2026-08-14-alert-reliability-improvements.md)
- [`../../repos.json`](../../repos.json)
