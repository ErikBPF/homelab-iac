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

  # Non-fleet devices (not in the fleet SSOT). Stale entries removed 2026-06-29
  # (ARP-confirmed down): homeassistant 52:54:00:80:4a:0e → .205 and
  # Discovery bc:24:11:57:ac:19 → .40.
  static_res = {
    "4a:83:5c:f1:34:95" = {
      name       = "Homeassistant"
      fixed_ip   = "192.168.1.205"
      network_id = "5e3cdb8a933186073f310966"
    }
    "52:12:8b:03:7c:9d" = {
      name       = "Sun"
      fixed_ip   = "192.168.10.10"
      network_id = local.main_net
    }
    "98:83:89:e2:39:c2" = {
      name     = "nixos-andre-wifi"
      fixed_ip = "192.168.10.108"
    }
    "c4:ad:34:2e:74:5d" = {
      name       = "Mikrotik servidor"
      fixed_ip   = "192.168.10.2"
      network_id = local.main_net
    }
    "a0:48:1c:75:11:c0" = {
      name     = "Falcon Heavy"
      fixed_ip = "192.168.10.20"
    }
    "ca:20:15:19:9f:42" = {
      name       = "truenas"
      fixed_ip   = "192.168.10.25"
      network_id = local.main_net
    }
    "2c:c8:1b:c8:47:76" = {
      name       = "Mikrotik Sala"
      fixed_ip   = "192.168.10.3"
      network_id = local.main_net
    }
    "a6:1a:fe:f0:e6:7c" = {
      name       = "Hubble"
      fixed_ip   = "192.168.10.30"
      network_id = local.main_net
    }
    "92:73:cb:e8:62:00" = {
      name       = "Soyuz"
      fixed_ip   = "192.168.10.45"
      network_id = local.main_net
    }
    "8a:5b:a8:51:fc:30" = {
      name       = "Starlink0"
      fixed_ip   = "192.168.10.50"
      network_id = local.main_net
    }
    "de:14:55:f5:39:54" = {
      name       = "Starlink1"
      fixed_ip   = "192.168.10.51"
      network_id = local.main_net
    }
    "a2:76:c0:eb:bb:22" = {
      name       = "Starlink2"
      fixed_ip   = "192.168.10.52"
      network_id = local.main_net
    }
    "56:a3:f1:6e:8f:83" = {
      name       = "Starlink3"
      fixed_ip   = "192.168.10.53"
      network_id = "5e3cdb8a933186073f310966"
    }
    "b0:4a:39:41:b5:41" = {
      name       = "roborock-vacuum-a15"
      fixed_ip   = "192.168.10.72"
      network_id = local.main_net
    }
    "0e:48:d5:b7:b8:77" = {
      name       = "LC-39"
      fixed_ip   = "192.168.10.80"
      network_id = local.main_net
    }
  }
}

inputs = {
  reservations = merge(local.static_res, local.fleet_res)
}
