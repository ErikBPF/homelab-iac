include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//wlan"
}

# Shared IDs — all three SSIDs sit on the Default network + default AP/user group.
locals {
  user_group_id = "5e3cdb8a933186073f310967"
  network_id    = "5e3cdb8a933186073f310966"
  ap_group_ids  = ["5e3cdb8a933186073f310970"]
}

# Imported from the live UDM (Phase 1). Passphrases come from .env via get_env,
# never committed. All three SSIDs sit on the Default network + default usergroup.
inputs = {
  wlan_passphrases = {
    "Que Wifi?"   = get_env("UNIFI_WLAN_PSK_QUE")
    "Wifi Errado" = get_env("UNIFI_WLAN_PSK_ERRADO")
    "Fast"        = get_env("UNIFI_WLAN_PSK_FAST")
  }

  wlans = {
    "Que Wifi?" = {
      security      = "wpapsk"
      user_group_id = local.user_group_id
      network_id    = local.network_id
      ap_group_ids  = local.ap_group_ids
      wlan_band     = "both"
      pmf_mode      = "disabled"
      no2ghz_oui    = false
    }
    "Wifi Errado" = {
      security      = "wpapsk"
      user_group_id = local.user_group_id
      network_id    = local.network_id
      ap_group_ids  = local.ap_group_ids
      wlan_band     = "both"
      pmf_mode      = "disabled"
    }
    "Fast" = {
      security      = "wpapsk"
      user_group_id = local.user_group_id
      network_id    = local.network_id
      ap_group_ids  = local.ap_group_ids
      wlan_band     = "both"
      wpa3_support  = true
      pmf_mode      = "required"
    }
  }
}
