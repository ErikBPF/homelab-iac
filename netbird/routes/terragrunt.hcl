include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//routes"
}

locals {
  group_ids = {
    admins = "d99f2h8i7llg00bf0kig"
  }
}

inputs = {
  group_ids = local.group_ids
  routes = {
    "homelab-lan" = {
      network_id            = "homelab-lan"
      description           = "Home LAN through Kepler; excluded from Tailscale clients."
      network               = "192.168.10.0/24"
      peer                  = "d9kvdjoi7llg00fm2dng"
      groups                = ["admins"]
      access_control_groups = ["admins"]
      masquerade            = true
    }
  }
}
