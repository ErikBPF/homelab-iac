#!/usr/bin/env bats

@test "Buzz is reachable from managed NetBird clients only" {
  run grep -F 'name          = "managed-clients-buzz"' netbird/policies/terragrunt.hcl
  [ "$status" -eq 0 ]
  run grep -F 'description   = "Buzz relay access over NetBird."' netbird/policies/terragrunt.hcl
  [ "$status" -eq 0 ]
  run grep -F 'sources       = ["admins", "fleet-clients", "fleet-servers"]' netbird/policies/terragrunt.hcl
  [ "$status" -eq 0 ]
  run grep -F 'destinations  = ["fleet-servers"]' netbird/policies/terragrunt.hcl
  [ "$status" -eq 0 ]
  run grep -F 'ports         = ["3000"]' netbird/policies/terragrunt.hcl
  [ "$status" -eq 0 ]
}
