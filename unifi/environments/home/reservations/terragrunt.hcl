include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//reservations"
}

# Imported from the live UDM (Phase 1). Keyed by MAC, sorted by fixed IP.
inputs = {
  reservations = {
    "4a:83:5c:f1:34:95" = {
      name       = "Homeassistant"
      fixed_ip   = "192.168.1.205"
      network_id = "5e3cdb8a933186073f310966"
    }
    "52:12:8b:03:7c:9d" = {
      name       = "Sun"
      fixed_ip   = "192.168.10.10"
      network_id = "6642461fb9ca59447793c3da"
    }
    "98:83:89:e2:39:c2" = {
      name     = "nixos-andre-wifi"
      fixed_ip = "192.168.10.108"
    }
    "54:bf:64:28:cb:2e" = {
      name     = "nix-erik"
      fixed_ip = "192.168.10.125"
    }
    "c4:ad:34:2e:74:5d" = {
      name       = "Mikrotik servidor"
      fixed_ip   = "192.168.10.2"
      network_id = "6642461fb9ca59447793c3da"
    }
    "a0:48:1c:75:11:c0" = {
      name     = "Falcon Heavy"
      fixed_ip = "192.168.10.20"
    }
    "52:54:00:80:4a:0e" = {
      name     = "homeassistant"
      fixed_ip = "192.168.10.205"
    }
    "64:51:06:1a:f8:1a" = {
      name       = "Moon"
      fixed_ip   = "192.168.10.210"
      network_id = "6642461fb9ca59447793c3da"
    }
    "b4:2e:99:92:4f:8b" = {
      name       = "HTPC"
      fixed_ip   = "192.168.10.220"
      network_id = "5e3cdb8a933186073f310966"
    }
    "b8:27:eb:40:2b:1d" = {
      name     = "archinaut"
      fixed_ip = "192.168.10.225"
    }
    "b8:27:eb:15:7e:48" = {
      name     = "archinaut-wifi"
      fixed_ip = "192.168.10.226"
    }
    "74:56:3c:47:d1:77" = {
      name     = "kepler"
      fixed_ip = "192.168.10.230"
    }
    "ca:20:15:19:9f:42" = {
      name       = "truenas"
      fixed_ip   = "192.168.10.25"
      network_id = "6642461fb9ca59447793c3da"
    }
    "2c:c8:1b:c8:47:76" = {
      name       = "Mikrotik Sala"
      fixed_ip   = "192.168.10.3"
      network_id = "6642461fb9ca59447793c3da"
    }
    "a6:1a:fe:f0:e6:7c" = {
      name       = "Hubble"
      fixed_ip   = "192.168.10.30"
      network_id = "6642461fb9ca59447793c3da"
    }
    "bc:24:11:57:ac:19" = {
      name     = "Discovery"
      fixed_ip = "192.168.10.40"
    }
    "92:73:cb:e8:62:00" = {
      name       = "Soyuz"
      fixed_ip   = "192.168.10.45"
      network_id = "6642461fb9ca59447793c3da"
    }
    "8a:5b:a8:51:fc:30" = {
      name       = "Starlink0"
      fixed_ip   = "192.168.10.50"
      network_id = "6642461fb9ca59447793c3da"
    }
    "de:14:55:f5:39:54" = {
      name       = "Starlink1"
      fixed_ip   = "192.168.10.51"
      network_id = "6642461fb9ca59447793c3da"
    }
    "a2:76:c0:eb:bb:22" = {
      name       = "Starlink2"
      fixed_ip   = "192.168.10.52"
      network_id = "6642461fb9ca59447793c3da"
    }
    "56:a3:f1:6e:8f:83" = {
      name       = "Starlink3"
      fixed_ip   = "192.168.10.53"
      network_id = "5e3cdb8a933186073f310966"
    }
    "b0:4a:39:41:b5:41" = {
      name       = "roborock-vacuum-a15"
      fixed_ip   = "192.168.10.72"
      network_id = "6642461fb9ca59447793c3da"
    }
    "0e:48:d5:b7:b8:77" = {
      name       = "LC-39"
      fixed_ip   = "192.168.10.80"
      network_id = "6642461fb9ca59447793c3da"
    }
  }
}
