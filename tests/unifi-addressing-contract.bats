#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "Main uses dynamic 20-199 and clean reserved addresses" {
  run python3 - \
    "$REPO_ROOT/unifi/environments/home/network/terragrunt.hcl" \
    "$REPO_ROOT/unifi/environments/home/reservations/terragrunt.hcl" \
    "$REPO_ROOT/fleet.json" <<'PY'
import json,pathlib,re,sys
network,reservations,fleet=map(lambda p:pathlib.Path(p).read_text(),sys.argv[1:])
main=re.search(r'"Main"\s*=\s*\{(.*?)\n\s*\}',network,re.S).group(1)
assert 'dhcp_start    = "192.168.10.20"' in main
assert 'dhcp_stop     = "192.168.10.199"' in main
assert re.findall(r'fixed_ip\s*=\s*"192\.168\.10\.(\d+)"',reservations)==["2","3","4","200","205"]
assert "roborock" not in reservations.lower()
hosts=json.loads(fleet)["hosts"]
assert {name:hosts[name]["ip"] for name in (
  "discovery","orion","kepler","pathfinder","archinaut","homeassistant"
)} == {
  "discovery":"192.168.10.210",
  "orion":"192.168.10.220",
  "kepler":"192.168.10.230",
  "pathfinder":"192.168.10.215",
  "archinaut":"192.168.10.225",
  "homeassistant":"192.168.10.115",
}
PY
  [ "$status" -eq 0 ]
}
