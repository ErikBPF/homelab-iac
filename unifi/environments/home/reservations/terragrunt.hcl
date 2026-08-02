include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//reservations"
}

# DHCP fixed-IP reservations. Fleet hosts are GENERATED from the vendored fleet
# SSOT (fleet.json, published by desktop-nixos `flake.fleet`; RFC 2026-06-29 P1,
# D9 publish-and-pin) — change a host IP there, re-vendor fleet.json, re-apply.
# Non-fleet devices stay hand-authored in `static_res` below.
locals {
  fleet    = jsondecode(file(find_in_parent_folders("fleet.json")))
  main_net = "6642461fb9ca59447793c3da"

  # Preserve each fleet host's current network_id (others stay unpinned/null) so
  # wiring the SSOT is a no-op on live state — only names/IPs flow from fleet.json.
  fleet_network_ids = {
    "64:51:06:1a:f8:1a" = local.main_net # discovery
    "b4:2e:99:92:4f:8b" = local.main_net # orion
  }

  # Reservations for fleet hosts with a MAC+IP (incl. the .115 HA appliance, adopted
  # via `terragrunt import`). voyager (public, no MAC) / laptop (roaming) fall out.
  fleet_res = {
    for name, h in local.fleet.hosts :
    h.mac => {
      name       = name
      fixed_ip   = h.ip
      network_id = lookup(local.fleet_network_ids, h.mac, null)
      note       = null
    }
    if h.mac != null && h.ip != null
  }

  # Network infrastructure only. Ordinary hosts live in the .200-.254 reserved
  # zone via fleet_res; unpinned clients use the .20-.199 dynamic pool.
  static_res = {
    "c4:ad:34:2e:74:5d" = {
      name       = "Mikrotik servidor"
      fixed_ip   = "192.168.10.2"
      network_id = local.main_net
    }
    "2c:c8:1b:c8:47:76" = {
      name       = "Mikrotik Sala"
      fixed_ip   = "192.168.10.3"
      network_id = local.main_net
    }
    "48:da:35:6f:69:ae" = {
      name       = "nanokvm"
      fixed_ip   = "192.168.10.4"
      network_id = local.main_net
    }
    "34:29:8f:75:b6:3c" = {
      name       = "endeavour-wired"
      fixed_ip   = "192.168.10.200"
      network_id = local.main_net
    }
    "40:d1:33:47:03:47" = {
      name       = "endeavour-wifi"
      fixed_ip   = "192.168.10.205"
      network_id = local.main_net
    }
  }
}

inputs = {
  reservations = merge(local.static_res, local.fleet_res)
}
