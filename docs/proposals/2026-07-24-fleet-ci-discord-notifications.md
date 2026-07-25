# Fleet CI notifications in Discord

**Status:** Implemented
**Date:** 2026-07-24
**Activated:** 2026-07-25

## Decision

Use one Discord channel, `#ci`, for failure-only notifications from each
repository's primary CI workflow. Security and deployment messages remain in
their dedicated Discord channels.

Each notification contains only the repository, ref, actor, and GitHub Actions
run link. Logs stay in GitHub. Payloads disable mentions.

## Coverage

- `desktop-nixos`: `Check`
- `homelab-iac`: `ci`
- `servarr`: `Validate`
- `homelab-gitops`: `validate`
- `hermes-flake`: `build`
- `hermes-skills`: `Validate skills`
- `home-assistant-config`: `Validate HA config`
- `klipper-biqu`: `Validate`
- `kindle-dash`: `CI`
- `opencode-flake`: `check`
- `codex-flake`: `check`

`ha-harness` and `cosmo-notes` have no primary CI workflow. Their
security-only workflows do not post to `#ci`.

## Transport

The webhook is stored as the per-repository GitHub Actions secret
`DISCORD_CI_WEBHOOK`. A final `notify-ci` job runs only when a required CI job
fails. Missing secrets produce a workflow notice rather than exposing or
failing on secret material.

The native Discord `/github` compatibility endpoint is not used because it
cannot provide the same narrow workflow and failure-only routing.

## Noise gate

Do not post successes, job starts, commits, scanner findings, deployment
results, or full logs. Reassess after 30 days; keep failure-only routing unless
operators need a measurable recovery signal.
