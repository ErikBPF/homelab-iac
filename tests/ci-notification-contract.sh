#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while read -r repo workflow; do
  file="$root/references/repos/$repo/.github/workflows/$workflow"
  grep -qs 'DISCORD_CI_WEBHOOK' "$file" ||
    { echo "$repo: missing CI webhook" >&2; exit 1; }
  grep -qs 'allowed_mentions:{parse:\[\]}' "$file" ||
    { echo "$repo: CI mentions not disabled" >&2; exit 1; }
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
