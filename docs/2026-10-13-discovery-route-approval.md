# Discovery subnet-route recovery

**Status:** source regression and wired Orion plan pass; merge/apply pending.
**Stage / revision:** source GREEN and reviewed delivery plan / 2, 2026-10-13.
**Checkout:** `worktrees/discovery-route-approval-20261013`, branch
`fix/discovery-route-approval-20261013`.

## Outcome and human seed

“we need to use .210. SSH discovery and validate it and adguard”; “inspect and
validate tailscale”; “do fix and enable routes”. Approved scope is Discovery's
four already-advertised host routes: `192.168.10.1/32`, `192.168.10.2/32`,
`192.168.10.4/32`, and `192.168.10.210/32`. DNS must keep `.210`.

Discovery and AdGuard already work: LAN address assigned, forwarding enabled,
container healthy, UDP/TCP DNS serving private/public answers on LAN and tailnet
listeners. Tailscale's authenticated API confirms authorized Discovery node
`nBNPLvBqRK11CNTRL` advertises all four routes but has `enabledRoutes: []`.
Endeavour accepts subnet routes, yet `.210` traffic follows roaming Wi-Fi.
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

Follow the existing `2026-09-07-tailnet-orion-apollo.md` recipe on wired Orion,
using an isolated checkout outside synchronization. SSH preflight confirms
`192.168.10.1 dev enp4s0 src 192.168.10.220`. Transfer pinned tools and the source
candidate; selectively load six sanctioned Sops bootstrap values into process
environment through encrypted SSH stdin, never plaintext files or output.
Keep remote state locking enabled and use a bounded 60-second lock wait.
Two SSH tool-copy attempts timed out; Orion then fetched the exact pinned
OpenTofu closure from the binary cache successfully. No tool version changed.
OAuth capability preflight successfully issued a token with `devices:routes`
write and `devices:routes:read` scopes; no credential scope change was needed.
Independent review confirms the narrow resource, rollback and plan gates;
runtime approval and connectivity remain unproven until deployment.

Before saved-plan apply, require exactly one resource creation with the intended
node and routes, no ACL or NanoKVM change, and no deletes. Recheck live identity
and empty enabled routes to detect concurrent changes. After apply, require API
readback, Endeavour route delivery, UDP/TCP `.210` DNS, normal TLS-verified
LiteLLM HTTPS, unchanged ACL/DNS, and a zero-diff plan. An unauthenticated 401 is
an ingress reachability check, not successful model execution.

## Continuing work and recovery

No routes have been enabled by this change yet. User subsequently authorized
“create pr, merge to main and apply”; deployment must use merged main.
Preserve canonical unrelated LiteLLM changes. If plan
contains unrelated drift, stop rather than target around it. Rollback means
changing this resource's routes to an empty list and applying a reviewed plan;
this removes approvals and restores the broken roaming path. Do not destroy the
device, alter shared ACL grants, disable locking, or force-unlock state.
