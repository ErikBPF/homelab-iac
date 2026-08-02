#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while read -r repo workflow; do
  file="$root/references/repos/$repo/.github/workflows/$workflow"
  grep -qs 'DISCORD_CI_WEBHOOK' "$file" ||
    { echo "$repo: missing CI webhook" >&2; exit 1; }
  grep -Fqs 'CLEYTIN_USER_ID: "1532710143517659356"' "$file" ||
    { echo "$repo: missing Cleytin user ID" >&2; exit 1; }
  grep -Fqs 'content:("<@"+$cleytin+">")' "$file" ||
    { echo "$repo: CI does not mention Cleytin" >&2; exit 1; }
  grep -Fqs 'allowed_mentions:{users:[$cleytin]}' "$file" ||
    { echo "$repo: CI does not allow the Cleytin mention" >&2; exit 1; }
done <<'EOF'
desktop-nixos check.yml
homelab-iac ci.yml
servarr validate.yml
homelab-gitops validate.yml
hermes-flake build.yml
hermes-skills validate.yml
home-assistant-config validate.yaml
klipper-biqu validate.yml
kindle-dash ci.yml
opencode-flake check.yml
codex-flake check.yml
EOF
