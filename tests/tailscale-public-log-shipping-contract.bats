#!/usr/bin/env bats

@test "public SSH hosts can ship journals only to Loki" {
  repo_root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  policy="$repo_root/tailscale/acl/policy.hujson"

  run grep -F '"src": ["voyager", "vanguard"], "dst": ["discovery:3100"]' "$policy"
  [ "$status" -eq 0 ]

  run grep -F '{"src": "voyager", "accept": ["discovery:3100"]}' "$policy"
  [ "$status" -eq 0 ]

  run grep -F '{"src": "vanguard", "accept": ["discovery:3100"]}' "$policy"
  [ "$status" -eq 0 ]
}
