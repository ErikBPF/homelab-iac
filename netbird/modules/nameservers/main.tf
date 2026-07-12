resource "netbird_nameserver_group" "this" {
  for_each = var.nameserver_groups

  name                   = each.key
  description            = each.value.description
  enabled                = each.value.enabled
  primary                = each.value.primary
  domains                = each.value.domains
  search_domains_enabled = each.value.search_domains_enabled
  groups                 = [for g in each.value.groups : var.group_ids[g]]

  nameservers = [
    for ns in each.value.nameservers : {
      ip      = ns.ip
      ns_type = ns.ns_type
      port    = ns.port
    }
  ]
}
