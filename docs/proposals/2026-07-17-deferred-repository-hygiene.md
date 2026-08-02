# Deferred repository hygiene

**Status:** Completed 2026-08-02

This ledger preserves follow-up work that was intentionally excluded from the
Endeavour workspace consolidation. Re-audit live state before acting; the
observations below are not authorization to discard another repository's work
or bypass a required check.

## Other dirty repositories

- [x] Revisit the unrelated dirty worktrees reported by the fleet audit.
  Classify each change with that repository's `AGENTS.md`, preserve legitimate
  work, and remove synchronization artifacts only after its canonical machine
  is explicitly chosen.
- [x] Keep cross-repository changes leaf-first. Do not fold uncommitted sister
  repository state into `desktop-nixos`.

## Blocked feature pull requests

- [x] Re-audit
  [`home-assistant-config#65`](https://github.com/ErikBPF/home-assistant-config/pull/65).
  Its topology check was failing when deferred; do not merge until the branch is
  current and every required check is green.
- [x] Confirm the superseded Kepler Whisper branch is closed after its complete
  change set lands through the Endeavour consolidation PR.

## Dependency pull requests

- [x] Re-audit
  [`home-assistant-config#56`](https://github.com/ErikBPF/home-assistant-config/pull/56)
  after Renovate's three-day stability gate resolves. Its functional checks
  were green, but `renovate/stability-days` was still pending.
- [x] Onboard `ErikBPF/renovate-config` into its own explicit repository
  allowlist and add a repository preset consumer. This lets Renovate pin and
  update the runner's own GitHub Actions instead of leaving major tags
  floating.

## Completion record

- All 15 inventoried local repositories are clean on `main` with exactly one
  worktree each. The fleet audit passes.
- All 15 inventoried GitHub repositories have zero open pull requests and only
  the `main` branch. Unrelated repositories owned by the same account remain
  outside this coordination scope.
- `home-assistant-config` PRs
  [#65](https://github.com/ErikBPF/home-assistant-config/pull/65) and
  [#56](https://github.com/ErikBPF/home-assistant-config/pull/56) merged with
  their required checks green.
- Superseded `desktop-nixos` Whisper PR
  [#26](https://github.com/ErikBPF/desktop-nixos/pull/26) is closed; its
  complete consolidation path merged through
  [#28](https://github.com/ErikBPF/desktop-nixos/pull/28).
- [`renovate-config` PR #7](https://github.com/ErikBPF/renovate-config/pull/7)
  added the runner repository to its explicit allowlist, added its shared
  preset consumer, and added a regression contract.
