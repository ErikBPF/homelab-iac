# Public airflow-mcp repository

Human seed (verbatim): “use my homelab iac to create a public repo called airflow-mcp. License it as apache 2.0. Ground on other famous MCPs for capbilities, docs, and auth methods.”

## Outcome and ownership

`ErikBPF/airflow-mcp` is created through the existing `github/repos` Terragrunt component. The public Python project owns its package, Apache-2.0 license, documentation and CI; homelab-iac owns repository lifecycle, merge policy, Actions permissions, vulnerability alerts and branch protection. No unrelated repository settings are intentionally changed.

## Changes and decisions

The repository entry uses public visibility, squash-only merges, merged-branch cleanup, read-only workflow tokens, disabled workflow PR approval, dependency alerts and protected `main` requiring the `test` CI check. Auto-merge is disabled. Creation targets the repository plus its two Actions permission resources and vulnerability alerts; protection is applied after the first branch exists. Repository description/topics and private vulnerability reporting follow the module's existing GitHub-owned metadata boundary.

The package extracts the validated Airflow pilot into a portable stdio MCP. It keeps existing-run restart semantics and private connection-file delivery, replaces fixed host access with operator configuration, starts read-only, and separates write and privileged-export enablement. Upstream bearer tokens or private username/password token-exchange files authenticate to Airflow. Remote HTTP/OAuth hosting is explicitly unsupported. Design references document the observed GitHub MCP, Grafana MCP, Python SDK and MCP authorization patterns without copying their source.

## Evidence and limits

The repository-catalogue test first failed because `airflow-mcp` was absent, then passed after adding it. All ten GitHub hardening/private-repository Bats tests pass; HCL formatting passes. The saved creation plan contained exactly four additions, zero changes and zero deletions, and applied successfully. The plan/state use the established encrypted backend. The normal devenv shell stalled in Nix evaluation; installed tools were used with the same documented dotenv-to-state wiring and canonical SecretSpec GitHub credential, without displaying values. Bats was run through an offline Nix shell.

The portable package passes sixteen unit tests and builds an sdist/wheel. Independent review identified a helper-output validation gap; a failing regression proved it, and exports now require the expected connection object/ID/type. Importing the module also starts read-only. Publication contents were checked for secret files, token/private-key patterns and private-host references. Both live MCP suites passed against the Orion Airflow 3.3.1 sandbox: existing-run mutations/connections and listing/regex/timestamp boundaries. An initial concurrent run caused a timestamp-boundary assertion while the other suite mutated fixtures; sequential validation passed. GitHub recognizes Apache-2.0, the public main branch is published, and [CI passed](https://github.com/ErikBPF/airflow-mcp/actions/runs/44067436908).

Branch protection is active and imported into encrypted IaC state. The initial targeted protection plan pulled in three unrelated missing repositories; a narrowed variable override instead triggered prevent-destroy safeguards. Neither plan was applied. The exact protection rule was created through GitHub and imported as `github_branch_protection.main["airflow-mcp"]`. Import initially failed because the unused app-management provider had an empty token; supplying the existing authorized token for provider initialization resolved it. No app installation was changed. A final targeted plan proposed only the same three unrelated repository additions, with no Airflow protection changes; it was not applied. GitHub confirms strict `test` checks, administrator enforcement, conversation resolution, and blocked force-push/deletion.

## Recovery and remaining scope

Repository destruction is blocked by the shared module; do not delete the repository to roll back a code issue. Revert a code commit or disable optional tools instead. Production RBAC, hosted OAuth, external secret backend edits and PyPI publication remain outside this initial release. Existing unrelated working-tree changes are preserved. The task's IaC source change is submitted separately in [PR #172](https://github.com/ErikBPF/homelab-iac/pull/172); it excludes local user edits and remains awaiting review.

## CR reconciliation — 2026-11-17

[Hackerman finding](https://github.com/ErikBPF/homelab-iac/pull/172#issuecomment-6946022226), reviewed head `784e0ab831c5e9c101df44fdb993124db8702096`: P1, stale base retains retired `agentmemory`, `sail`, and `sail-dev`. Confirmed in source. The earlier extra plan additions were caused by the stale checkout, not an outstanding request to restore those repositories.

Disposition: fixed by replaying only the Airflow commits onto current `origin/main` (`2a6a4fa`) in an isolated worktree. The catalogue keeps all three retirements and current status-check settings; the private-repository assertion stays 15. The resulting functional diff adds only the Airflow entry and its expected test key. All ten GitHub contract tests pass. A live Terragrunt plan targeting Airflow protection, Actions permissions, workflow permissions and vulnerability alerts reports `No changes. Your infrastructure matches the configuration.` No apply was needed. This is scoped verification, not a full-fleet drift claim. Existing `.env.sops` and `devenv.nix` user changes remain untouched in the original checkout. The previous bootstrap receipts above describe observed history, not the rebased desired state. Fresh CR is required for the rewritten head.
