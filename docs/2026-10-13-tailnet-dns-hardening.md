# DNS and Tailscale hardening delivery

**Status:** DNS candidate is import-only; live identity precondition passes with
no remote changes; probe review repairs pass; publication and apply pending.
**Stage / revision:** reviewed delivery candidate / 3, 2026-10-13.

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

Live homelab split DNS targets `.210`, absent from source. Provider 0.29.2 imports
by domain. Desktop's pinned drift artifact predates route management; refresh
existing owners rather than add monitoring machinery.

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
   all four SWAG/DNS contracts. Reviewed wired Orion candidate plan contains one
   import and zero remote mutations. Regenerate from merged source, apply that
   plan, require unchanged complete DNS readback and follow-up exit 0.
2. **Identity guard, homelab-iac.** One native mocked plan rejects missing
   Discovery. Seven production-HCL expression fixtures cover valid, missing,
   duplicate, replaced, unauthorized, wrong-tag and wrong-address identities.
   All pass; nested-block provider mock overrides are unsupported by this runner.
   Current route approvals and ACL/NanoKVM must remain no-op.
   Wired candidate plan verifies real credential read capability: Discovery's
   blocking precondition reports `pass`, with zero remote mutations. Plan JSON
   omits data lookup values; receipt checks configuration and precondition status,
   not missing data-change entries. Initial receipt classification failed twice
   before this schema-grounded correction; acceptance was not relaxed.
3. **Roaming probe, desktop-nixos.** Retain behavioral RED/GREEN tests for route,
   DNS and TLS failures and unavailable environment. On genuine roaming
   Endeavour, require all four routes through Tailscale, UDP/TCP DNS at `.210`,
   ordinary system resolution and TLS-verified normal HTTPS. LiteLLM 401 is an
   unauthenticated transport check, not model success. Print PASS only after all
   checks; never repair or restart automatically.
   First draft passed focused unittest, lint, formatting and docs checks in
   `worktrees/tailscale-hardening-20261013`; actual roaming Endeavour checks passed.
   A repeat caught a transient TCP DNS failure honestly, with exit 1 and no PASS;
   later checks passed, cause unproven. Review found false PASS on home secondary
   addresses/static/bridge routes and wrong peer names. Six new cases failed
   before conservative environment and exact-hostname repairs; normal/optimized
   tests and real probe then passed. Native guard owns node-ID authorization.
4. **Published pin, desktop-nixos.** Land IaC leaf first, then update exact source
   URL and single-input lock to its merged revision. Pin contract must fail on old
   source and pass candidate. Review Discovery dry-build closure, deploy only
   authorized changes, verify active checker consumes the new pinned artifact.

## Delivery, limits and recovery

Independent review found CI's OpenTofu wrapper drops console stdin; disable that
wrapper so durable expression fixtures use the real binary. CI stays
credential-free. Remove temporary glue and rerun affected checks before PRs. Use existing
wired Orion isolated-checkout recipes, private encrypted plans, selective Sops
environment loading and enabled state locking. DNS rollback must preserve live
rule: removing the managed resource normally deletes it, so undo ownership only
through reviewed state-only unmanagement. Native guard rollback removes the
precondition, not approvals. Desktop rollback restores previous pinned generation.
Stop on unrelated plan/closure changes or after three repairs of one failure.
Full candidate source transfer timed out once; retry transferred only the owning
Tailnet modules and backend (40 KiB) successfully. This changed no live service.
