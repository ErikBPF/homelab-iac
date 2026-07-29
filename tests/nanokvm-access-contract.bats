#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "NanoKVM keeps its current address through DHCP reservation" {
  reservations="$REPO_ROOT/unifi/environments/home/reservations/terragrunt.hcl"

  grep -qF '"48:da:35:6f:69:ae" = {' "$reservations"
  grep -qF 'name       = "nanokvm"' "$reservations"
  grep -qF 'fixed_ip   = "192.168.10.157"' "$reservations"
}

@test "NanoKVM direct access is limited to admin tailnet devices" {
  policy="$REPO_ROOT/tailscale/acl/policy.hujson"

  grep -qF '"nanokvm":   "100.125.209.99"' "$policy"
  grep -qF '"192.168.10.157/32": ["erikbogado@gmail.com"]' "$policy"
  grep -qF '{"action": "accept", "src": ["laptop", "endeavour", "pathfinder"], "dst": ["nanokvm:22,443"]}' "$policy"
  grep -qF '{"src": "laptop", "accept": ["nanokvm:22", "nanokvm:443"]}' "$policy"
  grep -qF '{"src": "orion", "deny": ["nanokvm:22", "nanokvm:443"]}' "$policy"
}

@test "NanoKVM device key does not expire" {
  module="$REPO_ROOT/tailscale/modules/acl/main.tf"

  grep -qF 'resource "tailscale_device_key" "nanokvm"' "$module"
  grep -qF 'device_id           = "nu53rVuxF711CNTRL"' "$module"
  grep -qF 'key_expiry_disabled = true' "$module"
}
