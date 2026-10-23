# DNS and Tailscale hardening delivery

**Status:** IaC adoption complete without remote mutations; desktop PR #377
merged with green CI; candidate built on Orion and delivered through signed cache
to Discovery. Rollback gates and activation remain pending.
**Stage / revision:** IaC E2E and implementation RV complete; receipt RV reconciled / 6, 2026-10-14.

## Outcome, seed and boundaries

Human seed: “any other improvements and hardenings?” followed by “do all but 4”.
Accepted: adopt existing homelab split DNS, refresh Discovery's published IaC
pin, retain roaming checks and guard against silent Discovery re-enrollment.
Delivery answer “PR, merge and deploy” explicitly covers wired Orion state
adoption and Discovery deployment.

Administrative ACL tightening is excluded. Keep `.210`, the four existing host
routes, existing ACL grants, AdGuard lifecycle and client Tailscale preferences.
No server-wide auto-approval, resolver redesign, paid completions or fleet-wide
deployment. Preserve unrelated dirty checkouts.

## Grounding and decisions

Before adoption, live homelab split DNS targeted `.210` but source omitted it;
desktop's pinned artifact also predated route management. Provider 0.29.2 imports
by domain. Existing owners suffice; no monitoring machinery added.

Grill rejected singular lookup, which selects the first hostname match. Plural
exact-hostname lookup plus blocking precondition requires one authorized device
with pinned node, expected tag and tailnet address. Approval target stays pinned.
Native checks avoid custom OAuth hooks/runtime dependencies. Saved plans are
stale: require fresh identity/advertisement read immediately before apply.

Desktop owns client fleet/diagnostics. Independent environment checks distinguish
unavailable roaming from broken paths; missing routes off-LAN fail, never skip.

## Vertical slices and verification

1. **DNS adoption, homelab-iac.** New source contract failed because the homelab
   entry was absent; adding the existing resolver and declarative import passes
   all four SWAG/DNS contracts. Merged-source wired Orion apply completed one
   import, zero added/changed/destroyed; complete DNS readback was unchanged and
   follow-up detailed exit code was 0.
2. **Identity guard, homelab-iac.** One native mocked plan rejects missing
   Discovery. Seven production-HCL expression fixtures cover valid, missing,
   duplicate, replaced, unauthorized, wrong-tag and wrong-address identities.
   All pass; nested-block provider mock overrides are unsupported by this runner.
   Route approvals and ACL/NanoKVM remained no-op.
   Wired merged-source apply verifies real credential read capability: Discovery's
   blocking precondition reports `pass`, with zero added/changed/destroyed and
   follow-up detailed exit code 0. Initial receipt parsing failed twice; plan JSON
   omits lookup values, so corrected receipt checks configuration/precondition
   status. Acceptance was not relaxed.
3. **Roaming probe, desktop-nixos.** Retain behavioral RED/GREEN tests for route,
   DNS and TLS failures and unavailable environment. On genuine roaming
   Endeavour, require all four routes through Tailscale, UDP/TCP DNS at `.210`,
   ordinary system resolution and TLS-verified normal HTTPS. LiteLLM 401 is an
   unauthenticated transport check, not model success. Print PASS only after all
   checks; never repair or restart automatically.
   Review found false PASS for home secondary addresses/static/bridge routes and
   wrong peer names. Six cases failed before repairs; normal/optimized tests and
   independent live probe then passed. One repeat caught transient TCP DNS failure
   with exit 1/no PASS; later checks passed, cause unproven. Native guard owns
   node-ID authorization.
4. **Published pin, desktop-nixos.** IaC PR #133 merged at
   `d487d53ea4df11765054e13c75b5f41f00ece307`; consumer PR #377 pins that revision
   and merged as `2f33efc7990954283aff401f8deef91593b5f000`, with 11 CI checks
   passing. Old-pin assertion failed before update; eight pin tests now pass.
   Targeted Discovery dry-build passed with explicit Orion Tailscale builder and
   zero client jobs. Actual probes passed on `10.115.78.0/24` and `192.168.1.0/24`;
   host activation and active-checker verification remain pending. Canonical
   [desktop delivery receipt](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/roaming-dns-probe.md)
   records signed-cache delivery and unchanged system/profile state.

## Delivery, limits and recovery

Parent-observed E2E used only the hash-verified Tailnet archive at merged revision,
in `/var/tmp/tailnet-hardening-main-20261014.IS7sPK` on wired Orion
(`100.72.85.73`; LAN route `enp4s0`, source `192.168.10.220`). Pre/post complete
DNS nameservers/preferences/search paths/split nameservers, policy, device
registrations and routes were unchanged. Identity precondition passed for unique
pinned Discovery. No credentials were rotated or printed.

All 95 local Bats tests passed after initializing the pinned provider submodule.
That initial S04 failure and GC-removed unrooted tools were infrastructure failures,
not behavior RED. Exact `1.12.1`/`1.0.4` tools were restored/rooted before planning.

Discovery profile advanced from generation 128 (`s31`) to 129 (`v6rpgw`) alongside
successful unattended boot-staging; running (`iacvrg`) and booted (`d8plj2`)
closures remain distinct and unchanged. User authorized preserving/superseding
129 and a standard rollback wrapper around unchanged running OS. No profile write
or activation occurred in this task; wrapper and exclusive-window checks remain
pending. Same input also supplies Telstar capture code, with no-restart/no-stop
guards unchanged. Stop on unrelated closure changes.

Review repaired CI's stdin-dropping OpenTofu wrapper; CI remains credential-free.
Plans were private/encrypted with state locking. DNS ownership rollback must be
state-only: normal resource removal deletes live rule. Guard rollback removes
precondition, not approvals. Desktop recovery restores recorded running OS, not
mutable data. Full source transfer timed out once; Tailnet-only 40 KiB retry
succeeded without service changes. Three-repair cap remains. First receipt draft
is preserved in ignored harness `tailnet-dns-hardening-receipt-draft-4.md`.
