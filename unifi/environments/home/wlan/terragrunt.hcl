include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//wlan"
}

# All three SSIDs sit on the Default network + Default user/AP group. Resolve
# them by name in the module so the IDs follow the controller instead of going
# stale when an object is recreated.
locals {
  network_name    = "Default"
  user_group_name = "Default"
}

# Imported from the live UDM (Phase 1). Passphrases come from .env via get_env,
# never committed. All three SSIDs sit on the Default network + default usergroup.
inputs = {
  network_name     = local.network_name
  user_group_name  = local.user_group_name
  ap_group_default = true

  wlan_passphrases = {
    "Que Wifi?"   = get_env("UNIFI_WLAN_PSK_QUE")
    "Wifi Errado" = get_env("UNIFI_WLAN_PSK_ERRADO")
    "Fast"        = get_env("UNIFI_WLAN_PSK_FAST")
  }

  wlans = {
    "Que Wifi?" = {
      security   = "wpapsk"
      wlan_band  = "both"
      pmf_mode   = "disabled"
      no2ghz_oui = false
    }
    "Wifi Errado" = {
      security  = "wpapsk"
      wlan_band = "both"
      pmf_mode  = "disabled"
    }
    "Fast" = {
      security     = "wpapsk"
      wlan_band    = "both"
      wpa3_support = true
      pmf_mode     = "required"
    }
  }
}
