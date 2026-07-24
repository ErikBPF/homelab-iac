#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

jq -e '
  length == 13
  and all(.[]; .name and .responsibility and .path)
  and ([.[].name] | unique | length) == 13
' "$root/repos.json" >/dev/null

while IFS= read -r path; do
  test -L "$root/$path"
  test -d "$root/$path/.git"
done < <(jq -r '.[].path' "$root/repos.json")

recipes="$(just --justfile "$root/justfile" --summary)"
for recipe in status audit docs-check fleet-drift fleet-update test; do
  grep -qw "$recipe" <<<"$recipes"
done

"$root/bin/homelab" audit
"$root/bin/homelab" docs-check
bash "$root/tests/security-notification-contract.sh"
bash "$root/tests/deploy-notification-contract.sh"
