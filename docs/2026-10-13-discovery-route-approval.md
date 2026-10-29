# Discovery subnet-route recovery

**Status:** merged and applied; roaming DNS/HTTPS and zero-diff plan pass.
**Stage / revision:** deployment, E2E and review receipt / 3, 2026-10-13.
**Checkout:** `worktrees/discovery-route-approval-20261013`, branch
`fix/discovery-route-approval-20261013`.

## Outcome and human seed

“we need to use .210. SSH discovery and validate it and adguard”; “inspect and
validate tailscale”; “do fix and enable routes”. Approved scope is Discovery's
four already-advertised host routes: `192.168.10.1/32`, `192.168.10.2/32`,
`192.168.10.4/32`, and `192.168.10.210/32`. DNS must keep `.210`.

Discovery and AdGuard already work: LAN address assigned, forwarding enabled,
container healthy, UDP/TCP DNS serving private/public answers on LAN and tailnet
listeners. Before repair, the authenticated API confirmed authorized Discovery
node `nBNPLvBqRK11CNTRL` advertised all four routes but had `enabledRoutes: []`.
Endeavour accepted subnet routes, yet `.210` traffic followed roaming Wi-Fi.
Effective policy equals repository policy. All 43 existing ACL tests plus an
Endeavour DNS/HTTPS probe pass server-side validation. Permission is not approval.

## Change and decision

Existing `tailscale/modules/acl/main.tf` gains one
`tailscale_device_subnet_routes.discovery` resource, pinned to that node and those
four `/32`s. Provider 0.29.2 supports this resource. Explicit device approval
avoids widening auto-approval to every `tag:server` identity and needs no
re-enrollment, advertisement changes, or new Terraform unit/backend.
Existing ACL, NanoKVM key-expiry management, DNS and credentials remain unchanged.
New node enrollment would require consciously updating this pinned identity.

The live homelab split-DNS rule is absent from DNS source. Reconciliation is
separate: this recovery neither removes it nor expands the DNS deployment scope.
The source contract runs in the existing infrastructure CI step.

## Evidence and delivery gates

`python3 tests/tailscale-discovery-routes-contract.py` first failed with
`AssertionError: Discovery subnet-route approval resource is missing`; after the
resource change it prints `PASS: Discovery-only subnet-route approval contract`.
`tofu fmt -check tailscale/modules/acl/main.tf` and `git diff --check` pass.
This source check does not prove runtime routing.
All 11 `tests/tailscale-*.bats` tests also pass. The wired Orion saved plan
contains exactly one creation, `tailscale_device_subnet_routes.discovery`,
with the intended node and four routes; existing ACL and NanoKVM are no-op.
Filtered JSON review asserts these boundaries before any apply.

User authorized “create pr, merge to main and apply”. [PR #130](https://github.com/ErikBPF/homelab-iac/pull/130)
merged as `d79df3c282ff668e19f9d6df13f9f38f36dc12f7`; lint, secret-scan and
GitGuardian checks passed. Deployment used a fresh archive of that merged
revision on wired Orion, following `2026-09-07-tailnet-orion-apollo.md`.
Source hash matched; LAN route was `enp4s0 src 192.168.10.220` and MinIO health
returned HTTPS 200. Six bootstrap values were selectively loaded into process
environment through encrypted SSH stdin; no plaintext credential files or
output. State locking stayed enabled with a 60-second wait.
Two SSH tool-copy attempts timed out; Orion then fetched the exact pinned
OpenTofu closure from the binary cache successfully. No tool version changed.
OAuth capability preflight successfully issued a token with `devices:routes`
write and `devices:routes:read` scopes; no credential scope change was needed.
Independent review confirmed the narrow resource, rollback and plan gates.

The merged-source plan again showed exactly one creation; live identity and empty
approvals were rechecked immediately before saved-plan apply. Apply reported
`Resources: 1 added, 0 changed, 0 destroyed.` Readback confirms all four routes
enabled. Endeavour receives them and routes each through `tailscale0 table 52`.
UDP/TCP DNS at `.210` and normal system DNS resolve LiteLLM to `.210`.
TLS-verified normal HTTPS returns AdGuard 302 and unauthenticated LiteLLM 401,
both connected to `.210`. ACL hash, split DNS and device registrations are
unchanged; the subsequent detailed-exitcode plan exits 0. The client check failed
before approval with `Approved routes not delivered to Endeavour` and passes
afterward. This proves ingress reachability, not authenticated model execution.
Private receipts/runners remain in the ignored harness directory as
`discovery-route-*.py` and `discovery-routes-*.json`; they contain no credentials.

## Continuing work and recovery

Runtime recovery is complete. Separate work remains for the pre-existing DNS
source drift; no reboot or paid model completion was tested. Canonical unrelated
LiteLLM changes remain untouched. Future unrelated plan drift must stop deployment
rather than be targeted around. Rollback means
changing this resource's routes to an empty list and applying a reviewed plan;
this removes approvals and restores the broken roaming path. Do not destroy the
device, alter shared ACL grants, disable locking, or force-unlock state.

## 2026-10-29 follow-up: exclusive source ownership

The recovery and deployment receipt above describes 2026-10-13. A later source
review found that the ACL policy also auto-approved the same four routes for a
user account. The accepted follow-up decision is “Discovery-only approval”;
deployment remains separate. The policy now removes those automatic approvals
and leaves the pinned Discovery resource, all access rules and policy test cases
unchanged. The existing source contract also rejects nonempty route
auto-approvals that overlap any protected route, including broader prefixes.
Unrelated route auto-approvals remain permitted.

[Tailscale's auto-approver reference](https://tailscale.com/docs/reference/syntax/policy-file#auto-approvers)
states that a route permission includes its subnets and that automatic approval
is evaluated when an advertisement first arrives. This source change neither
inventories nor revokes approvals already present on other devices, including
manual approvals. It does not establish exclusive live ownership or current
routing behavior. A separately authorized deployment must inspect existing
approved routes and reconcile any overlapping approval on another device before
claiming that outcome.

The source contract first failed with `Route auto-approval overlaps Discovery's
managed routes`, then passed after removing the policy entries. Validation uses
`python3 tests/tailscale-discovery-routes-contract.py`. Fifteen private copied-policy
checks cover exact and broader approvals, unrelated IPv4/IPv6 routes, empty
approvers, HuJSON comments and trailing commas, duplicate keys, and invalid CIDRs.
All matched their expected outcomes; all 12 existing `tests/tailscale-*.bats`
checks and `git diff --check` also passed. These are source checks, not Tailscale
policy-engine or routing tests. No provider, state, API, or deployment operation
was used for this follow-up. Reverting the policy removal would restore
account-wide automatic approval and requires revisiting the accepted ownership
decision; it is not the recovery rollback described above.
