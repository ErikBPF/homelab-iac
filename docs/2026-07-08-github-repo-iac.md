# GitHub repo settings as IaC — `github/` component

**Status:** Implemented for all 27 active owned repositories on 2026-07-22.
**Date:** 2026-07-08; fleet hardening expanded 2026-07-22

## Why

The desktop-nixos flake-input repos (`codex-flake`, `opencode-flake`, and
`hermes-flake`) each run a scheduled "auto-update" lane: bump the upstream
version → open a PR → enable auto-merge. On 2026-07-08 the codex and opencode
lanes were failing, in two stages, both caused by **repo settings that had
drifted off out-of-band** (not code):

1. `GitHub Actions is not permitted to create or approve pull requests.` — the
   *Allow GitHub Actions to create and approve pull requests* toggle
   (`can_approve_pull_request_reviews`) was OFF, so `create-pull-request` was
   denied.
2. `GraphQL: Auto merge is not allowed for this repository` — `allow_auto_merge`
   was OFF, so `gh pr merge --auto` failed even after the PR was created.

Both were fixed live via the REST API to unblock CI. This component codifies
them so they **cannot silently drift off again** — a repo-settings toggle in a
web UI is exactly the kind of state that belongs in IaC.

(The parallel hermes-flake failure was a code bug in its updater's version
regex, fixed in that repo — out of scope here.)

## What it manages

`github/` follows the same shape as `cloudflare/`: a `root.hcl` that generates
the provider + encrypted S3/MinIO state, a reusable module under
`modules/repo/`, and one unit `repos/` that instantiates it over a map.

Per repo, three resources:

| Resource | Owns | Fixes |
|---|---|---|
| `github_workflow_repository_permissions` | `default_workflow_permissions` (write) + `can_approve_pull_request_reviews` (true) | break #1 |
| `github_repository` | `allow_auto_merge` + merge-strategy surface | break #2 |
| `github_actions_repository_permissions` | `allowed_actions` (all) | — |

`github_repository` carries `prevent_destroy` + `archive_on_destroy` (never
delete a repo from a stray destroy) and `ignore_changes` on
description/topics/issue-wiki-project-download toggles — this component owns
**only** the merge/auto-merge/permission surface, not repo features.

Branch protection is enabled on every public repository: administrators are
enforced, force-push and deletion are disabled, conversations must resolve,
and proven CI checks remain required. GitHub Free does not offer branch
protection for private repositories; those are explicitly marked unsupported
while still receiving merge-strategy and Actions-permission hardening.
`required_checks` are recorded in the map for when it is turned on.

## Auth

Provider reads `GITHUB_TOKEN` + `GITHUB_OWNER` from the shell (`.env` via
dotenv), same pattern as `CLOUDFLARE_API_TOKEN`. See `.env.example`. Token
needs Administration:RW + Actions:RW on the three repos.

## Migration — import current state (zero-diff)

Validated locally against live GitHub with a local backend: the seeded map
mirrors current settings, so the import changes nothing real.

```
Plan: 9 to import, 0 to add, 3 to change, 0 to destroy.
```

The "3 to change" are `github_repository` gaining two **TF-only** meta
attributes (`archive_on_destroy`, `ignore_vulnerability_alerts_during_read`) —
neither writes to the GitHub API. No settings change.

Steps (from the devenv shell, after adding `GITHUB_TOKEN`/`GITHUB_OWNER` to
`.env`):

1. In `github/repos/terragrunt.hcl`, flip the `imports` generate block to
   `disable = false`.
2. `cd github/repos && terragrunt init`
3. `terragrunt plan` — confirm `9 to import, 0 to add, 3 to change, 0 to destroy`
   and **no** attribute `->` diffs.
4. `terragrunt apply`
5. Flip `disable = true` again, commit (the imports block is a one-time tool).

Rollback: the import only writes state; to abandon, delete the
`github/repos/terraform.tfstate` object from MinIO — no repo settings were
changed.

## After migration

Repo settings drift is now caught by the same `bin/drift-check.sh` sweep that
covers the other components. To onboard another repo: add a key to the `repos`
map (defaults encode the fleet norm), re-enable imports for that key, plan,
apply.
