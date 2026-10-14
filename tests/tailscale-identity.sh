#!/usr/bin/env bash
# Offline native tests use the deployment unit's locked provider version.
set -euo pipefail
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
tofu="${TG_TF_PATH:-tofu}"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
cp "$root"/tailscale/modules/acl/*.tf "$test_dir/"
cp -R "$root/tailscale/modules/acl/tests" "$test_dir/"
cp "$root/tailscale/acl/.terraform.lock.hcl" "$test_dir/"
"$tofu" -chdir="$test_dir" init -backend=false -lockfile=readonly -input=false
"$tofu" -chdir="$test_dir" test -no-color
python3 "$root/tests/tailscale-identity-guard.py" "$tofu"
echo "PASS: native Discovery identity guard"
