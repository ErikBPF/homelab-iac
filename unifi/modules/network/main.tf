resource "unifi_network" "this" {
  for_each = var.networks

  name    = each.key
  purpose = each.value.purpose

  subnet        = each.value.subnet
  vlan_id       = each.value.vlan_id
  network_group = each.value.network_group
  domain_name   = each.value.domain_name
  igmp_snooping = each.value.igmp_snooping
  multicast_dns = each.value.multicast_dns

  dhcp_enabled     = each.value.dhcp_enabled
  dhcp_start       = each.value.dhcp_start
  dhcp_stop        = each.value.dhcp_stop
  dhcp_lease       = each.value.dhcp_lease
  dhcp_dns         = each.value.dhcp_dns
  dhcp_v6_dns_auto = each.value.dhcp_v6_dns_auto
  dhcp_v6_dns      = each.value.dhcp_v6_dns

  # IPv6 prefix-delegation / RA is auto-derived from the WAN (ISP-driven), not
  # declarative intent — leave it to the controller so plans stay clean.
  lifecycle {
    ignore_changes = [
      # `enabled` imports inconsistently (API null -> provider false); never let
      # an apply flip a live network's enabled flag.
      enabled,
      dhcp_v6_start, dhcp_v6_stop,
      ipv6_interface_type, ipv6_pd_interface, ipv6_pd_start, ipv6_pd_stop,
      ipv6_ra_enable, ipv6_ra_priority, ipv6_ra_valid_lifetime,
    ]
  }
}
