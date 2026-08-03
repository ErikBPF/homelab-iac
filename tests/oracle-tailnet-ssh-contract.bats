#!/usr/bin/env bats

@test "OCI does not expose fleet SSH to the public internet" {
  repo_root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  module="$repo_root/oracle/modules/instance/main.tf"

  run grep -F 'min = 2222' "$module"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "tailnet policy authorizes admins and denies ordinary servers" {
  repo_root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  policy="$repo_root/tailscale/acl/policy.hujson"

  grep -qF '"pathfinder": "100.102.248.13"' "$policy"
  grep -qF '{"src": "endeavour", "accept": ["voyager:2222", "vanguard:2222"]}' "$policy"
  grep -qF '{"src": "orion", "deny": ["voyager:2222", "vanguard:2222"]}' "$policy"
}
