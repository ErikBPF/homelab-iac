#!/usr/bin/env bats

@test "Voyager keeps its reserved public IP enabled" {
  run grep -F 'reserve_public_ip    = true' oracle/compute/terragrunt.hcl
  [ "$status" -eq 0 ]
}

@test "Voyager relay DNS is pinned to its reserved IP" {
  run grep -F 'voyager_relay_ip = "163.176.78.19"' cloudflare/dns/terragrunt.hcl
  [ "$status" -eq 0 ]
}
