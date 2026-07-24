#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while IFS= read -r path; do
  workflow_dir="$root/$path/.github/workflows"
  repo="${path##*/}"
  grep -Rqs 'DISCORD_SECURITY_WEBHOOK' "$workflow_dir" ||
    { echo "$repo: missing security webhook" >&2; exit 1; }
  grep -Rqs 'allowed_mentions:{parse:\[\]}' "$workflow_dir" ||
    { echo "$repo: Discord mentions not disabled" >&2; exit 1; }
done < <(jq -r '.[] | select(.name != "ha-harness") | .path' "$root/repos.json")
