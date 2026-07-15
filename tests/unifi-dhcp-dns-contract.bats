#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "Main DHCP advertises only AdGuard then Kepler" {
  run python3 - "$REPO_ROOT/unifi/environments/home/network/terragrunt.hcl" <<'PY'
import pathlib,re,sys
text=pathlib.Path(sys.argv[1]).read_text()
main=re.search(r'"Main"\s*=\s*\{(.*?)\n\s*\}',text,re.S).group(1)
match=re.search(r'dhcp_dns\s*=\s*\[(.*?)\]',main,re.S)
assert match, "Main dhcp_dns missing"
values=re.findall(r'"([^"]+)"',match.group(1))
assert values == ["192.168.10.210","192.168.10.230"], values
PY
  [ "$status" -eq 0 ]
}

@test "Default DHCP DNS remains omitted" {
  run python3 - "$REPO_ROOT/unifi/environments/home/network/terragrunt.hcl" <<'PY'
import pathlib,re,sys
text=pathlib.Path(sys.argv[1]).read_text()
default=re.search(r'"Default"\s*=\s*\{(.*?)\n\s*\}',text,re.S).group(1)
assert "dhcp_dns" not in default
PY
  [ "$status" -eq 0 ]
}

@test "network module preserves ordered list without set or sort" {
  run python3 - "$REPO_ROOT/unifi/modules/network/variables.tf" "$REPO_ROOT/unifi/modules/network/main.tf" <<'PY'
import pathlib,sys
variables=pathlib.Path(sys.argv[1]).read_text();module=pathlib.Path(sys.argv[2]).read_text()
assert "dhcp_dns      = optional(list(string))" in variables
assert "dhcp_dns     = each.value.dhcp_dns" in module
for forbidden in ("toset(","sort(","distinct("):
    assert forbidden not in module
PY
  [ "$status" -eq 0 ]
}

@test "CI runs every Bats contract" {
  run grep -F 'bats tests/*.bats' "$REPO_ROOT/.github/workflows/ci.yml"
  [ "$status" -eq 0 ]
}
