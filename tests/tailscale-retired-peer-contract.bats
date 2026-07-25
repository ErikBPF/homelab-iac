#!/usr/bin/env bats

@test "retired galaxy peer has no Tailscale policy access" {
  repo_root="$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)"

  run grep -nF galaxy "$repo_root/tailscale/acl/policy.hujson"

  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
