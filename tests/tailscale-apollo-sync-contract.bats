#!/usr/bin/env bats
@test "Apollo Syncthing is scoped to Orion" {
  policy="$BATS_TEST_DIRNAME/../tailscale/acl/policy.hujson"
  grep -qF '{"action": "accept", "src": ["apollo"], "dst": ["orion:22000"]}' "$policy"
  grep -qF '{"action": "accept", "src": ["orion"], "dst": ["apollo:22000"]}' "$policy"
  grep -qF '"deny": ["kepler:22000", "endeavour:22000"]' "$policy"
}
