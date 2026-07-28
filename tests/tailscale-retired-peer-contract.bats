#!/usr/bin/env bats

@test "retired galaxy peer has no Tailscale policy access" {
  repo_root="$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)"

  run grep -nF galaxy "$repo_root/tailscale/acl/policy.hujson"

  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "kepler can reach voyager restic receiver" {
  repo_root="$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)"
  policy="$repo_root/tailscale/acl/policy.hujson"

  grep -qF '"voyager":    "100.105.38.10"' "$policy"
  grep -qF '{"action": "accept", "src": ["kepler"], "dst": ["voyager:8000"]}' "$policy"
  grep -qF '{"src": "kepler", "accept": ["voyager:8000"]}' "$policy"
}
