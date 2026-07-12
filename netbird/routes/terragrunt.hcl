include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//routes"
}

# NetBird routes (RFC §3 — "routes if any"). DEFERRED / empty by design.
#
# The obvious route would expose the home LAN (192.168.10.0/24) to remote overlay
# peers so the split-DNS in ../nameservers actually resolves to reachable hosts.
# It is NOT scaffolded with a concrete route because two prerequisites are real
# decisions, not mechanical fills:
#
#   1. A routing PEER on the LAN. `netbird_route` needs `peer` or `peer_groups`
#      pointing at an enrolled peer that sits on 192.168.10.0/24 and forwards
#      traffic. discovery is the control-plane SERVER, not a client peer, so it
#      cannot be the router as-is — a LAN host (e.g. kepler/orion) must first be
#      enrolled as a managed peer (RFC §8.5).
#   2. An explicit "expose the LAN subnet over the overlay" security decision.
#      That widens blast radius and must be made deliberately (mirrors the
#      Tailscale subnet-router posture), not defaulted here.
#
# When both are settled, fill `routes` below, e.g.:
#
#   routes = {
#     "homelab-lan" = {
#       network_id  = "homelab-lan"
#       network     = "192.168.10.0/24"
#       peer        = "<enrolled-LAN-peer-id>"   # the routing gateway
#       groups      = ["fleet-clients"]           # who receives the route
#       masquerade  = true
#     }
#   }
#
# and paste the real group IDs into `group_ids` from ../groups' output (same
# hardcoded-ID-after-first-apply pattern as ../policies / ../nameservers).
locals {
  group_ids = {}
}

inputs = {
  group_ids = local.group_ids
  routes    = {}
}
