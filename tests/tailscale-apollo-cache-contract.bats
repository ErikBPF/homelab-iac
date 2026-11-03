#!/usr/bin/env bats

@test "Apollo reaches Orion's Nix cache" {
  policy="$BATS_TEST_DIRNAME/../tailscale/acl/policy.hujson"

  grep -qF '"apollo":     "100.77.14.27"' "$policy"
  grep -qF '{"action": "accept", "src": ["endeavour", "pathfinder", "kepler", "apollo"], "dst": ["orion:5000"]}' "$policy"
  grep -qF '{"src": "apollo", "accept": ["orion:5000"]}' "$policy"
  grep -qF '{"src": "s25-ultra-de-erik", "deny": ["orion:5000"]}' "$policy"
}

@test "Apollo Kubernetes API is admin-only" {
  policy="$BATS_TEST_DIRNAME/../tailscale/acl/policy.hujson"

  grep -qF '{"action": "accept", "src": ["endeavour", "pathfinder", "kepler"], "dst": ["apollo:6443"]}' "$policy"
  grep -qF '{"src": "endeavour", "accept": ["apollo:6443"]}' "$policy"
  grep -qF '{"src": "s25-ultra-de-erik", "deny": ["apollo:6443"]}' "$policy"
}
