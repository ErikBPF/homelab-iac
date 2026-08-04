#!/usr/bin/env bats

@test "endeavour can reach SWAG on discovery's tailnet IP" {
  repo_root="$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)"
  policy="$repo_root/tailscale/acl/policy.hujson"

  grep -qF '{"action": "accept", "src": ["endeavour"], "dst": ["discovery:80,443"]}' "$policy"
  grep -qF '{"src": "endeavour", "accept": ["discovery:80", "discovery:443"]}' "$policy"
  grep -qF '{"src": "orion", "deny": ["discovery:80", "discovery:443"]}' "$policy"
}
