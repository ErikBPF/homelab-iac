# Deferred repository hygiene

**Status:** TODO — deferred from the 2026-07-17 fleet audit

This ledger preserves follow-up work that was intentionally excluded from the
Endeavour workspace consolidation. Re-audit live state before acting; the
observations below are not authorization to discard another repository's work
or bypass a required check.

## Other dirty repositories

- [ ] Revisit the unrelated dirty worktrees reported by the fleet audit.
  Classify each change with that repository's `AGENTS.md`, preserve legitimate
  work, and remove synchronization artifacts only after its canonical machine
  is explicitly chosen.
- [ ] Keep cross-repository changes leaf-first. Do not fold uncommitted sister
  repository state into `desktop-nixos`.

## Blocked feature pull requests

- [ ] Re-audit
  [`home-assistant-config#65`](https://github.com/ErikBPF/home-assistant-config/pull/65).
  Its topology check was failing when deferred; do not merge until the branch is
  current and every required check is green.
- [ ] Confirm the superseded Kepler Whisper branch is closed after its complete
  change set lands through the Endeavour consolidation PR.

## Dependency pull requests

- [ ] Re-audit
  [`home-assistant-config#56`](https://github.com/ErikBPF/home-assistant-config/pull/56)
  after Renovate's three-day stability gate resolves. Its functional checks
  were green, but `renovate/stability-days` was still pending.
- [ ] Onboard `ErikBPF/renovate-config` into its own explicit repository
  allowlist and add a repository preset consumer. This lets Renovate pin and
  update the runner's own GitHub Actions instead of leaving major tags
  floating.

