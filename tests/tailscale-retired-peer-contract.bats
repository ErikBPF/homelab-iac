#!/usr/bin/env bats

@test "retired peers leave no policy references" {
  ! grep -qiE 'gemini|laptop' "$BATS_TEST_DIRNAME/../tailscale/acl/policy.hujson"
}

@test "Gemini has no remaining policy references" {
  ! grep -qi gemini "$BATS_TEST_DIRNAME/../tailscale/acl/policy.hujson"
}

@test "mobile SSH targets the active workstations only" {
  policy="$BATS_TEST_DIRNAME/../tailscale/acl/policy.hujson"
  grep -qF '{"action": "accept", "src": ["s25-ultra-de-erik"], "dst": ["orion:2222", "apollo:2222", "endeavour:2222"]}' "$policy"
  grep -qF '{"src": "s25-ultra-de-erik", "accept": ["orion:2222", "apollo:2222", "endeavour:2222"]}' "$policy"
  grep -qF '{"src": "s25-ultra-de-erik", "deny": ["pathfinder:2222", "discovery:2222", "kepler:2222", "archinaut:2222", "voyager:2222", "vanguard:2222"]}' "$policy"
}

@test "primary hosts cross-attach over SSH without fleet admin access" {
  policy="$BATS_TEST_DIRNAME/../tailscale/acl/policy.hujson"
  grep -qF '{"action": "accept", "src": ["orion"], "dst": ["apollo:2222"]}' "$policy"
  grep -qF '{"action": "accept", "src": ["apollo"], "dst": ["orion:2222"]}' "$policy"
  grep -qF '{"src": "apollo", "deny": ["kepler:2222", "discovery:2222"]}' "$policy"
}

@test "kepler can reach voyager restic receiver" {
  repo_root="$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)"
  policy="$repo_root/tailscale/acl/policy.hujson"

  grep -qF '"voyager":    "100.105.38.10"' "$policy"
  grep -qF '{"action": "accept", "src": ["kepler"], "dst": ["voyager:8000"]}' "$policy"
  grep -qF '{"src": "kepler", "accept": ["voyager:8000"]}' "$policy"
}
