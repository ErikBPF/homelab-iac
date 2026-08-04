#!/usr/bin/env bats

@test "endeavour can reach SWAG on discovery's tailnet IP" {
  repo_root="$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)"
  policy="$repo_root/tailscale/acl/policy.hujson"

  grep -qF '{"action": "accept", "src": ["endeavour"], "dst": ["discovery:80,443"]}' "$policy"
  grep -qF '{"src": "endeavour", "accept": ["discovery:80", "discovery:443"]}' "$policy"
  grep -qF '{"src": "orion", "deny": ["discovery:80", "discovery:443"]}' "$policy"
}

@test "k8s zone uses discovery's tailnet DNS" {
  module=tailscale/modules/dns/main.tf
  variables=tailscale/modules/dns/variables.tf
  unit=tailscale/dns/terragrunt.hcl

  grep -qF 'resource "tailscale_dns_split_nameservers" "this"' "$module"
  grep -qF 'for_each = var.split_nameservers' "$module"
  grep -qF 'type        = map(set(string))' "$variables"
  grep -qF '"k8s.pastelariadev.com" = ["100.76.140.121"]' "$unit"
}
