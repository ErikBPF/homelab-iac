include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//groups"
}

# Baseline groups for the default-deny policy set (RFC §6/§8). peers/resources
# stay empty at scaffold time — WP4 is IaC-only, no NetBird peers exist yet
# (that's WP1's client module + Phase O rollout). Populate them by re-applying
# once real peer IDs exist, same lifecycle as tailscale/acl's named hosts.
inputs = {
  groups = {
    "admins"         = {} # laptop/pathfinder/galaxy — mirrors tailscale/acl's admin set
    "fleet-servers"  = {} # always-on fleet hosts enrolled via setup key
    "fleet-clients"  = {} # interactive user devices enrolled via PocketID SSO
    "netbird-relays" = {} # discovery relay#1 + voyager relay#2 (+ relay#3, §4a)
  }
}
