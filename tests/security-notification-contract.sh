#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while IFS= read -r path; do
  workflow_dir="$root/$path/.github/workflows"
  repo="${path##*/}"
  grep -Rqs 'DISCORD_SECURITY_WEBHOOK' "$workflow_dir" ||
    { echo "$repo: missing security webhook" >&2; exit 1; }
  grep -RFqs 'CLEYTIN_USER_ID: "1532710143517659356"' "$workflow_dir" ||
    { echo "$repo: missing Cleytin user ID" >&2; exit 1; }
  grep -RFqs 'content:("<@"+$cleytin+">")' "$workflow_dir" ||
    { echo "$repo: security alert does not mention Cleytin" >&2; exit 1; }
  grep -RFqs 'allowed_mentions:{users:[$cleytin]}' "$workflow_dir" ||
    { echo "$repo: security alert does not allow the Cleytin mention" >&2; exit 1; }
  if [[ "$repo" == ha-harness ]]; then
    grep -RFqs "if: always() && steps.gitleaks.outcome == 'failure'" "$workflow_dir" ||
      { echo "$repo: manual security failure cannot notify" >&2; exit 1; }
  fi
done < <(jq -r '.[].path' "$root/repos.json")
