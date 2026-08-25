#!/usr/bin/env bats

@test "Galaxy S25 can SSH only to Gemini and Endeavour" {
  repo_root="$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)"
  policy="$repo_root/tailscale/acl/policy.hujson"

  grep -qF '"gemini":     "100.91.131.59"' "$policy"
  grep -qF '"galaxy-s25": "100.66.253.15"' "$policy"
  grep -qF '{"action": "accept", "src": ["galaxy-s25"], "dst": ["gemini:2222", "endeavour:2222"]}' "$policy"
  grep -qF '{"src": "galaxy-s25", "accept": ["gemini:2222", "endeavour:2222"]}' "$policy"
  grep -qF '{"src": "galaxy-s25", "deny": ["laptop:2222", "pathfinder:2222", "discovery:2222", "kepler:2222", "orion:2222", "archinaut:2222", "voyager:2222", "vanguard:2222"]}' "$policy"
}

@test "Endeavour and Gemini can sync only on Syncthing" {
  repo_root="$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)"
  policy="$repo_root/tailscale/acl/policy.hujson"

  grep -qF '{"action": "accept", "src": ["endeavour"], "dst": ["gemini:22000"]}' "$policy"
  grep -qF '{"action": "accept", "src": ["gemini"], "dst": ["endeavour:22000"]}' "$policy"
  grep -qF '{"src": "endeavour", "accept": ["gemini:22000"]}' "$policy"
  grep -qF '{"src": "gemini", "accept": ["endeavour:22000"]}' "$policy"
}

@test "kepler can reach voyager restic receiver" {
  repo_root="$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)"
  policy="$repo_root/tailscale/acl/policy.hujson"

  grep -qF '"voyager":    "100.105.38.10"' "$policy"
  grep -qF '{"action": "accept", "src": ["kepler"], "dst": ["voyager:8000"]}' "$policy"
  grep -qF '{"src": "kepler", "accept": ["voyager:8000"]}' "$policy"
}
