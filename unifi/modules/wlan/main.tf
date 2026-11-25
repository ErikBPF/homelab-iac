# Resolve controller objects by name so the SSIDs follow the live controller
# instead of hardcoding IDs that go stale when the network/usergroup is
# recreated (the failure mode that made three SSIDs plan against a nonexistent
# network).
data "unifi_network" "this" {
  count = var.network_name == null ? 0 : 1
  name  = var.network_name
}

data "unifi_user_group" "this" {
  count = var.user_group_name == null ? 0 : 1
  name  = var.user_group_name
}

# The controller's built-in "all APs" group is matched with a blank name.
data "unifi_ap_group" "default" {
  count = var.ap_group_default ? 1 : 0
}

locals {
  network_id    = var.network_name == null ? null : data.unifi_network.this[0].id
  user_group_id = var.user_group_name == null ? null : data.unifi_user_group.this[0].id
  ap_group_ids  = var.ap_group_default ? [data.unifi_ap_group.default[0].id] : null
}

resource "unifi_wlan" "this" {
  for_each = var.wlans

  name          = each.key
  security      = each.value.security
  user_group_id = coalesce(each.value.user_group_id, local.user_group_id)
  network_id    = coalesce(each.value.network_id, local.network_id)
  passphrase    = lookup(var.wlan_passphrases, each.key, null)

  wlan_band       = each.value.wlan_band
  wpa3_support    = each.value.wpa3_support
  wpa3_transition = each.value.wpa3_transition
  pmf_mode        = each.value.pmf_mode
  hide_ssid       = each.value.hide_ssid
  is_guest        = each.value.is_guest
  ap_group_ids    = each.value.ap_group_ids != null ? each.value.ap_group_ids : local.ap_group_ids
  no2ghz_oui      = each.value.no2ghz_oui
}
