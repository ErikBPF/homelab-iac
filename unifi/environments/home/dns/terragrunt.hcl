include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//dns"
}

# Wildcard A-records derived from the vendored fleet SSOT (fleet.json, published
# by desktop-nixos `flake.fleet`). *.<zone> → the fronting host's IP. Re-sync
# fleet.json on a deliberate bump (RFC 2026-06-29 P2, D9 publish-and-pin).
# This corrected *.ai .112 (stale install IP) → kepler .230.
locals {
  fleet = jsondecode(file(find_in_parent_folders("fleet.json")))
}

inputs = {
  records = {
    for k, zone in local.fleet.ingress :
    "*.${zone.zone}" => {
      type   = "A"
      record = local.fleet.hosts[zone.host].ip
    }
  }
}
