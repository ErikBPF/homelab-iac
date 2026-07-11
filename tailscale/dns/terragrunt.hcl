include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//dns"
}

# Imported from the live tailnet. 192.168.10.210 is the homelab resolver;
# 100.76.140.121 is a tailnet node.
#
# TODO(vanguard R1, desktop-nixos docs/proposals/
# 2026-07-10-vanguard-second-oracle-node.md): vanguard's secondary CoreDNS
# resolver (services.fleetDns) belongs in this list right after discovery's
# 100.76.140.121, so fleet-name resolution survives discovery being down. Not
# added as a real entry yet — vanguard has no tailnet IP until it's
# provisioned (fleet.hosts.vanguard.tailscaleIp is null). The placeholder
# below is intentionally NOT a valid IP so a `terragrunt apply` run without
# replacing it fails loudly (Tailscale's API rejects it) instead of silently
# degrading live DNS. Replace with the real tailnet IP once vanguard joins the
# tailnet, then this apply is safe.
inputs = {
  nameservers = [
    "192.168.10.210", "100.76.140.121",
    # "PLACEHOLDER_REPLACE_ME_vanguard_tailnet_ip", # uncomment + fill in once vanguard is provisioned
    "1.1.1.1", "8.8.8.8"
  ]
  magic_dns    = true
  search_paths = []
}
