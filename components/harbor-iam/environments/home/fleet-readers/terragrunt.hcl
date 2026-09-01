locals {
  fleet = jsondecode(file("${get_repo_root()}/fleet.json"))
}

include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("fleet-readers-root.hcl")
}

terraform {
  source = "${get_repo_root()}/components/harbor-iam/modules/fleet-readers"
}

inputs = {
  fleet_hosts         = toset(keys(local.fleet.hosts))
  disabled_hosts      = toset([])
  rotation_generation = 1
}
