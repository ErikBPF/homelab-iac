include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//dns"
}

# Imported from the live tailnet. 192.168.10.210 is the homelab resolver
# (discovery LAN / AdGuard); 100.76.140.121 is discovery's tailnet IP.
#
# vanguard R1 (desktop-nixos docs/proposals/2026-07-10-vanguard-second-oracle-node.md):
# 100.90.247.79 is vanguard's secondary CoreDNS resolver (services.fleetDns),
# placed right after discovery so fleet-name resolution survives discovery
# being down before falling through to the public resolvers. The tailnet ACL
# grants everyone vanguard:53 (rule 2) so this fallback is actually reachable.
inputs = {
  nameservers = [
    "192.168.10.210", "100.76.140.121",
    "100.90.247.79",
    "1.1.1.1", "8.8.8.8"
  ]
  magic_dns    = true
  search_paths = []
}
