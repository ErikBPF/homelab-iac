#!/usr/bin/env bats

@test "Voyager keeps its reserved public IP enabled" {
  run grep -E '^[[:space:]]*reserve_public_ip[[:space:]]*=[[:space:]]*true$' oracle/compute/terragrunt.hcl
  [ "$status" -eq 0 ]
}
