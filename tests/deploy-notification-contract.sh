#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for repo in codex-flake opencode-flake hermes-flake; do
  workflow="$root/references/repos/$repo/.github/workflows/check.yml"
  [ "$repo" = hermes-flake ] &&
    workflow="$root/references/repos/$repo/.github/workflows/build.yml"
  grep -qs 'DISCORD_DEPLOYS_WEBHOOK' "$workflow" ||
    { echo "$repo: missing deploy webhook" >&2; exit 1; }
  grep -qs 'allowed_mentions:{parse:\[\]}' "$workflow" ||
    { echo "$repo: deploy mentions not disabled" >&2; exit 1; }
done
