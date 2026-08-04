#!/usr/bin/env bats

@test "NetBird LAN route excludes Endeavour" {
  route=netbird/routes/terragrunt.hcl

  grep -E '^[[:space:]]+groups[[:space:]]+= \["admins"\]$' "$route"
  grep -E '^[[:space:]]+access_control_groups[[:space:]]+= \["admins"\]$' "$route"
  ! grep -E '^[[:space:]]+(groups|access_control_groups)[[:space:]]+= \["fleet-clients"\]$' "$route"
}

@test "NetBird route omits empty mutually exclusive fields" {
  module=netbird/modules/routes/main.tf

  grep -F 'domains               = length(each.value.domains) == 0 ? null : each.value.domains' "$module"
  grep -F 'peer_groups           = length(each.value.peer_groups) == 0 ? null : [for g in each.value.peer_groups : var.group_ids[g]]' "$module"
}
