#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "monitoring names resolve to the Kubernetes ingress" {
  run python3 - "$REPO_ROOT/adguard/filtering/terragrunt.hcl" <<'PY'
import pathlib, re, sys

text = pathlib.Path(sys.argv[1]).read_text()
rewrites = dict(re.findall(r'^\s*"([^"]+)"\s*=\s*"([^"]+)"', text, re.M))
assert rewrites["grafana.homelab.pastelariadev.com"] == "192.168.10.250"
assert rewrites["prometheus.homelab.pastelariadev.com"] == "192.168.10.250"
assert rewrites["*.homelab.pastelariadev.com"] == "192.168.10.210"
PY
  [ "$status" -eq 0 ]
}

@test "monitoring cutover preserves active AdGuard policy" {
  run python3 - "$REPO_ROOT/adguard/filtering/terragrunt.hcl" <<'PY'
import pathlib, sys

text = pathlib.Path(sys.argv[1]).read_text()
for value in (
    '"HaGeZi Multi Pro++"',
    '"HaGeZi Threat Intelligence Feeds"',
    '"OISD Big"',
    '"@@||pastelariadev.com^"',
    '"||telemetry.mozilla.org^"',
):
    assert value in text, value
PY
  [ "$status" -eq 0 ]
}
