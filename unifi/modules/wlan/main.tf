resource "unifi_wlan" "this" {
  for_each = var.wlans

  name          = each.key
  security      = each.value.security
  user_group_id = each.value.user_group_id
  network_id    = each.value.network_id
  passphrase    = lookup(var.wlan_passphrases, each.key, null)

  wlan_band       = each.value.wlan_band
  wpa3_support    = each.value.wpa3_support
  wpa3_transition = each.value.wpa3_transition
  pmf_mode        = each.value.pmf_mode
  hide_ssid       = each.value.hide_ssid
  is_guest        = each.value.is_guest
  ap_group_ids    = each.value.ap_group_ids
  no2ghz_oui      = each.value.no2ghz_oui
}
