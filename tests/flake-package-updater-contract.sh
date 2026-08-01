#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

jq -e 'any(.[]; .name == "renovate-config")' "$root/repos.json" >/dev/null
bash "$root/references/repos/renovate-config/tests/package-updates-contract.sh"

test ! -e "$root/references/repos/codex-flake/.github/workflows/update-codex.yml"
test ! -e "$root/references/repos/opencode-flake/.github/workflows/update-opencode.yml"
test ! -e "$root/references/repos/hermes-flake/.github/workflows/update-hermes-agent.yml"

! grep -Eq 'nix (build|run)' "$root/references/repos/hermes-flake/scripts/update-version.sh"
! grep -Eq 'nix (build|run)' "$root/references/repos/opencode-flake/scripts/update-opencode.sh"
! grep -Eq 'nix (build|run)' "$root/references/repos/codex-flake/scripts/update-codex.sh"

echo "flake package updater contract OK"
