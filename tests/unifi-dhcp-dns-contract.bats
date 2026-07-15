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

@test "Default IPv4 DHCP DNS remains omitted" {
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
assert "dhcp_dns         = optional(list(string))" in variables
assert "dhcp_dns         = each.value.dhcp_dns" in module
for forbidden in ("toset(","sort(","distinct("):
    assert forbidden not in module
PY
  [ "$status" -eq 0 ]
}

@test "CI runs every Bats contract" {
  run grep -F 'bats tests/*.bats' "$REPO_ROOT/.github/workflows/ci.yml"
  [ "$status" -eq 0 ]
}

@test "IPv6 DHCP DNS is optional nullable and passed through without defaults" {
  run python3 - "$REPO_ROOT/unifi/modules/network/variables.tf" "$REPO_ROOT/unifi/modules/network/main.tf" <<'PY'
import pathlib,sys
variables=pathlib.Path(sys.argv[1]).read_text();module=pathlib.Path(sys.argv[2]).read_text()
assert "dhcp_v6_dns_auto = optional(bool)" in variables
assert "dhcp_v6_dns      = optional(list(string))" in variables
assert "dhcp_v6_dns_auto = each.value.dhcp_v6_dns_auto" in module
assert "dhcp_v6_dns      = each.value.dhcp_v6_dns" in module
import re
assert re.search(r'dhcp_v6_dns_auto\s*=\s*optional\(bool\)',variables)
PY
  [ "$status" -eq 0 ]
}

@test "only Main overrides DHCPv6 DNS; Default has no override and keeps provider default true" {
  run python3 - "$REPO_ROOT/unifi/environments/home/network/terragrunt.hcl" <<'PY'
import pathlib,re,sys
text=pathlib.Path(sys.argv[1]).read_text()
default=re.search(r'"Default"\s*=\s*\{(.*?)\n\s*\}',text,re.S).group(1)
main=re.search(r'"Main"\s*=\s*\{(.*?)\n\s*\}',text,re.S).group(1)
assert "dhcp_v6_dns_auto" not in default and "dhcp_v6_dns" not in default
assert re.search(r'dhcp_v6_dns_auto\s*=\s*false',main)
assert re.search(r'dhcp_v6_dns\s*=\s*\[\s*\]',main)
assert text.count("dhcp_v6_dns_auto") == 1
assert text.count("dhcp_v6_dns") == 2
PY
  [ "$status" -eq 0 ]
}

@test "IPv6 RA and PD exact ignore contract remains intact" {
  run python3 - "$REPO_ROOT/unifi/modules/network/main.tf" <<'PY'
import pathlib,re,sys
text=pathlib.Path(sys.argv[1]).read_text()
block=re.search(r'ignore_changes\s*=\s*\[(.*?)\n\s*\]',text,re.S).group(1)
block=re.sub(r'#.*','',block)
fields={field.strip() for field in block.replace('\n',' ').split(',') if field.strip()}
assert fields == {"enabled", "dhcp_v6_start", "dhcp_v6_stop", "ipv6_interface_type", "ipv6_pd_interface", "ipv6_pd_start", "ipv6_pd_stop", "ipv6_ra_enable", "ipv6_ra_priority", "ipv6_ra_valid_lifetime"}, fields
PY
  [ "$status" -eq 0 ]
}

@test "pinned UniFi 1.0.0 schema keeps DHCPv6 DNS optional with default true and max four" {
  run python3 - "$REPO_ROOT/unifi/environments/home/network/.terraform.lock.hcl" "$REPO_ROOT/tests/fixtures/unifi-network-v1.0.0-ipv6-dns-schema.json" <<'PY'
import json,pathlib,re,sys
lock=pathlib.Path(sys.argv[1]).read_text();schema=json.loads(pathlib.Path(sys.argv[2]).read_text())
provider=re.search(r'provider "registry\.opentofu\.org/filipowm/unifi"\s*\{(.*?)\n\}',lock,re.S).group(1)
assert re.search(r'version\s*=\s*"1\.0\.0"',provider)
auto=schema["dhcp_v6_dns_auto"];dns=schema["dhcp_v6_dns"]
assert auto["type"] == "bool" and auto["optional"] is True and auto["default"] is True
assert dns["type"] == ["list","string"] and dns["optional"] is True
assert dns["max_items"] == 4 and dns["min_items"] is None
PY
  [ "$status" -eq 0 ]
}
