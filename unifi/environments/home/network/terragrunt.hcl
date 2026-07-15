include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//network"
}

# Imported from the live UDM (Phase 1). WAN networks (Internet 1/2) are out of
# scope; OpenVPN USA is purpose=vpn-client which this provider cannot manage.
inputs = {
  networks = {
    "Default" = {
      purpose       = "corporate"
      subnet        = "192.168.1.1/24"
      dhcp_enabled  = true
      dhcp_start    = "192.168.1.6"
      dhcp_stop     = "192.168.1.254"
      domain_name   = "localdomain"
      multicast_dns = true
    }
    "Main" = {
      purpose       = "corporate"
      subnet        = "192.168.10.1/24"
      vlan_id       = 2
      dhcp_enabled  = true
      dhcp_start    = "192.168.10.60"
      dhcp_stop     = "192.168.10.230"
      dhcp_dns      = ["192.168.10.210", "192.168.10.230"]
      multicast_dns = true
    }
  }
}
