# Fleet flake package-updater CI hardening

**Status:** Partially deployed; App canary blocked by private Actions billing
**Date:** 2026-07-31
**Owners:** `renovate-config` for orchestration; each flake repository for its
package updater and CI gate

## Summary

Move the custom Codex, OpenCode, and Hermes package-update schedules behind the
existing `erikbpf-fleet-renovate` GitHub App. Keep package mutation logic in each
component repository and keep its normal pull-request CI authoritative.

The central updater must create at most one custom package-update PR per
repository and skip while it remains open. Package incompatibility belongs on
that PR as a failing required check, not as repeated scheduler failures. Retire
`GITHUB_TOKEN` PR creation and its approval, dispatch, polling, and recovery
workarounds after one App-backed update proves normal PR and push events.

## Incident evidence

Evidence sampled from GitHub Actions on 2026-07-31:

- [`hermes-flake` updater run 30671070012](https://github.com/ErikBPF/hermes-flake/actions/runs/30671070012)
  fails while applying `v2026.7.30`. The updater suppresses the underlying Nix
  output and reports only `Build failed for the new pin`.
- From 2026-07-30 23:54 UTC through 2026-07-31 22:48 UTC, the unchanged Hermes
  target produced 12 failed scheduled updater runs. This is one incompatible
  update reported as 12 infrastructure incidents.
- [`hermes-flake` PR #31](https://github.com/ErikBPF/hermes-flake/pull/31)
  contains the real package adaptation: set upstream's `HERMES_NIX_BUILD`
  marker and exclude the unavailable `tflite-runtime` wake extra from the eager
  Python 3.13 Linux full package. Both architecture jobs are now green.
- [`opencode-flake` PR #21](https://github.com/ErikBPF/opencode-flake/pull/21)
  was created by `github-actions[bot]`. Its `check` and `Security` runs both
  ended as `action_required` with zero jobs; the PR is blocked with no check
  contexts.
- [`opencode-flake` updater run 30538428514](https://github.com/ErikBPF/opencode-flake/actions/runs/30538428514)
  previously dispatched branch checks, enabled auto-merge, then held the
  scheduled job open until it timed out. The later `workflow_run` recovery
  removed the timeout but also removed the required pre-merge branch dispatch,
  exposing the approval gate again.
- Current `codex-flake` and `buzz-flake` runs are green. Codex has the same
  latent `GITHUB_TOKEN` PR-approval behavior; Buzz has no package updater.

GitHub documents this behavior: PRs created or updated with the repository
`GITHUB_TOKEN` enter an approval-required state. GitHub recommends a GitHub App
installation token or PAT when those PRs must run workflows without approval:
<https://docs.github.com/en/actions/concepts/security/github_token>.

## Root causes

### 1. Wrong identity for cross-workflow automation

The component updaters pass `secrets.GITHUB_TOKEN` to
`peter-evans/create-pull-request`. GitHub deliberately gates workflows caused
by that token. Manual approvals and explicit `workflow_dispatch` calls are
workarounds, not stable PR semantics.

The fleet already has the correct identity: `erikbpf-fleet-renovate`, installed
on all three repositories with Contents, Pull requests, Workflows, Issues, and
Commit statuses write access. Its GitHub Actions secret already lives in the
private `renovate-config` runner repository; the encrypted root-of-trust copy
remains in `desktop-nixos` sops. Spreading a PAT or the App private key into
every component repository would add runtime copies and another rotation path.

OpenCode's dispatch, merge-wait, and `workflow_run` variants all compensate for
events suppressed or gated by `GITHUB_TOKEN`. An App-authored PR needs none of
them: branch protection waits for required checks, auto-merge lands it, and the
App merge emits the normal publish-triggering `push` event.

### 2. Mutation and validation share one failure domain

`hermes-flake/scripts/update-version.sh` mutates the pin, performs package
builds, restores the files on failure, and exits before creating a PR. This
turns an expected upstream compatibility problem into a scheduler outage. No
persistent branch captures the attempted change or its failing logs.

Package validation already exists in each repository's PR workflow. Running it
before PR creation duplicates the gate and prevents that durable gate from
carrying the failure.

## Decision

### Central orchestration, local implementation

Add one scheduled package-update workflow to private `ErikBPF/renovate-config`.
It mints a short-lived token from the existing fleet Renovate App, checks out
the selected component repository, invokes that repository's updater, and
creates its PR with the App token. If any package-update PR is already open for
that repository, the job reports it and exits successfully; automation must not
overwrite maintainer fixes on a failed PR.

Component repositories retain version discovery, package mutation, hashes,
locks, and all CI gates. `renovate-config` owns only schedule, explicit scope,
App token minting, PR creation, auto-merge enablement, and scheduler alerts.

This extends the implemented fleet Renovate decision instead of creating a
second bot, PAT, or secret distribution system. GitHub App installation tokens
are short-lived and repository-scoped:
<https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app>.

### PR CI is the only package gate

Updater apply paths should stop building packages before PR creation. They
must leave the smallest complete mechanical update they can produce. Normal PR
CI decides mergeability. Green checks auto-merge and normal `push` CI publishes;
failed checks leave one reviewable PR while later schedules skip it. Do not
weaken required checks. Any retained updater-side Nix command must preserve
`--print-build-logs` rather than discard both streams.

## Rollout

Land leaf-first:

1. **Current recovery:** merge green Hermes PR #31. Approve and verify OpenCode
   PR #21 once, or replace it through the App-backed canary; do not merge it
   without `check` and `package-build` success.
2. **Register ownership:** add `renovate-config` to `repos.json`; implementation
   must belong to an inventoried component repository.
3. **Component preparation:** make each updater's apply path mutation-only.
   Keep one small script check for version parsing and produced-file coverage.
4. **Central canary:** add the App-backed workflow in `renovate-config` for
   OpenCode. Confirm the PR gets jobs immediately, auto-merge waits for both
   required contexts, and the merge starts main-branch publish/verification.
5. **Fleet expansion:** add Codex and Hermes to the same explicit matrix. Reuse
   current updater scripts; do not copy package logic centrally.
6. **Delete workarounds:** remove component schedules, required-check
   `workflow_dispatch`, merge polling, and post-merge recovery only after each
   repository passes one live update cycle.

## File coverage

Expected implementation surface:

- `homelab/repos.json` — register `renovate-config` ownership;
- `renovate-config/.github/workflows/package-updates.yml` — central schedule,
  App token, explicit matrix, one-open-PR guard, PR creation, auto-merge;
- `hermes-flake/scripts/update-version.sh` — mutation only; visible diagnostics;
- `hermes-flake/.github/workflows/update-hermes-agent.yml` — retire after
  canary;
- `opencode-flake/scripts/update-opencode.sh` and
  `codex-flake/scripts/update-codex.sh` — mutation only where validation is
  currently embedded;
- `opencode-flake/.github/workflows/update-opencode.yml` and
  `codex-flake/.github/workflows/update-codex.yml` — retire after canary;
- existing `build.yml`, `check.yml`, `security.yml`, and branch protection —
  remain authoritative; no check bypass.

No consumer, deployment, FlakeHub naming, package interface, or runtime secret
path changes.

## Acceptance gates

- App private key gains no new runtime copy outside `renovate-config`; the
  existing encrypted sops source remains authoritative and no PAT exists.
- An App-authored canary PR starts all normal PR jobs with no approval banner
  and no `action_required` run.
- Required package checks attach to the PR head SHA and block auto-merge on
  failure.
- Successful auto-merge emits normal main `push` CI and FlakeHub verification.
- While a package-update PR is open, another scheduled run skips it without
  changing its branch.
- No component scheduled updater or merge-poll loop remains after migration.
- Existing fleet Renovate allowlist stays explicit; no `autodiscover`.

## Constraints

- Central runner failure blocks all package bumps. This is already the accepted
  Renovate failure domain and its one security alert remains the correct signal.
- App compromise has fleet write scope; retain current explicit installation
  list and private-key storage.
- Mechanical updaters cannot repair arbitrary upstream packaging changes.
  Permanent behavior is one reviewable failed PR.
- Do not move package scripts into `renovate-config`. That would make the
  coordinator duplicate component implementation.
- Reject manual approval/dispatch workarounds, PATs, extra App-key copies, and
  unsafe Renovate post-upgrade execution. Existing App auth plus local scripts
  covers the requirement.

## Implementation record

Prepared 2026-07-31 across the owning repositories:

- registered `renovate-config` in the coordination inventory;
- added its App-authenticated package-update matrix and one-open-PR guard;
- made all three component updater scripts mutation-only;
- moved validation into existing required PR checks with focused updater tests;
- prepared retirement of the three `GITHUB_TOKEN` scheduler workflows and
  OpenCode's `workflow_run` recovery contract.

Leaf preparation PRs
[`codex-flake#17`](https://github.com/ErikBPF/codex-flake/pull/17),
[`opencode-flake#22`](https://github.com/ErikBPF/opencode-flake/pull/22), and
[`hermes-flake#32`](https://github.com/ErikBPF/hermes-flake/pull/32) merged
after required checks passed. Central runner PR
[`renovate-config#4`](https://github.com/ErikBPF/renovate-config/pull/4) also
merged.

The first live dispatch,
[`renovate-config` run 30673989454](https://github.com/ErikBPF/renovate-config/actions/runs/30673989454),
failed all matrix jobs before step 1. GitHub annotated each job: recent account
payments failed or the spending limit must be increased. The repository has no
self-hosted runner. The central workflow was manually disabled to prevent
hourly zero-step failures, and component schedulers remain active.

Activation remains unclaimed. Restore private Actions billing or approve a
runner/repository-visibility change, re-enable the central workflow, and rerun
the OpenCode canary before retiring component schedulers.
