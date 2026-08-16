#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

test ! -e "$root/docs/proposals/2026-07-10-netbird-selfhosted-overlay.md"
test -f "$root/docs/decisions/2026-08-10-pangolin-netbird-retirement.md"
grep -Fq 'NetBird retired 2026-08-10' \
  "$root/docs/decisions/2026-08-10-pangolin-netbird-retirement.md"
! grep -Fq 'proposals/2026-07-10-netbird-selfhosted-overlay.md' \
  "$root/docs/README.md" "$root/docs/proposal-index.md"

if grep -Eq 'length == [0-9]+' "$root/bin/homelab" "$root/tests/contracts.sh"; then
  echo "repository validation must not hardcode the inventory size" >&2
  exit 1
fi

jq -e '
  length > 0
  and all(.[]; .name and .responsibility and .path)
  and ([.[].name] | unique | length) == length
  and ([.[].path] | unique | length) == length
' "$root/repos.json" >/dev/null

while IFS= read -r path; do
  test -L "$root/$path"
  test -d "$root/$path/.git"
done < <(jq -r '.[].path' "$root/repos.json")

test -L "$root/CLAUDE.md"
test "$(readlink "$root/CLAUDE.md")" = "AGENTS.md"
grep -Fxq '/worktrees/' "$root/.gitignore"
grep -Fxq '/graphify-out/' "$root/.gitignore"
grep -Fxq '/worktrees/' "$root/.graphifyignore"
test -f "$root/docs/decisions/2026-08-04-agent-worktree-policy.md"
grep -Fq \
  '(decisions/2026-08-04-agent-worktree-policy.md)' \
  "$root/docs/README.md"
grep -Fq '### 2026-08-03 — public-host SSH containment' \
  "$root/docs/proposals/2026-07-25-runtime-security-monitoring.md"
if grep -Fq 'Identify 15 unmapped offsite SSH accepts' \
  "$root/docs/proposal-index.md"; then
  echo "runtime-security index still treats contained public SSH as an open source-review gate" >&2
  exit 1
fi

recipes="$(just --justfile "$root/justfile" --summary)"
for recipe in status audit docs-check fleet-drift fleet-update test; do
  grep -qw "$recipe" <<<"$recipes"
done

"$root/bin/homelab" audit
"$root/bin/homelab" docs-check
bash "$root/tests/security-notification-contract.sh"
bash "$root/tests/deploy-notification-contract.sh"
bash "$root/tests/ci-notification-contract.sh"
bash "$root/tests/cleytin-alert-contract.sh"
bash "$root/tests/runtime-security-inventory-contract.sh"
bash "$root/tests/flake-package-updater-contract.sh"
