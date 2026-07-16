#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
module=$root/adguard/modules/config/main.tf
variables=$root/adguard/modules/config/variables.tf
unit=$root/adguard/config/terragrunt.hcl
contract=$root/tests/fixtures/adguard-config-model/contract.json
render=$(mktemp); trap 'rm -f "$render"' EXIT
for path in "$module" "$variables" "$unit"; do test -f "$path"; done
python3 - "$module" "$variables" "$unit" "$contract" <<'PY'
import json,pathlib,re,sys
module,variables,unit=map(pathlib.Path,sys.argv[1:4]);contract=json.loads(pathlib.Path(sys.argv[4]).read_text())
main=module.read_text();types=variables.read_text();inputs=unit.read_text();combined="\n".join((main,types,inputs)).lower()
assert 'resource "adguard_config" "this"' in main
for field in contract["provider_fields"]:
    assert re.search(rf"^\s*{field}\s*=",main,re.M),field
for forbidden in ("password","private_key","certificate_chain","users","static_leases"):
    assert forbidden not in combined,forbidden
assert 'source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//config"' in inputs
assert 'version = "= 1.7.0"' in (module.parent/"versions.tf").read_text()
assert "runtime" not in combined and ".state" not in combined
PY
tofu fmt -check "$root/adguard/modules/config" >/dev/null
terragrunt hcl fmt --check "$unit" >/dev/null
UNIFI_STATE_PASSPHRASE=fixture-only terragrunt render --json \
  --working-dir "$root/adguard/config" --log-level error >"$render"
jq -e --slurpfile contract "$contract" '
  (.inputs.config | keys | sort) == ($contract[0].provider_fields | sort) and
  ([.inputs.config | .. | objects | keys[]] | any(. == "password" or . == "private_key" or . == "certificate_chain" or . == "users" or . == "static_leases") | not)
' "$render" >/dev/null
