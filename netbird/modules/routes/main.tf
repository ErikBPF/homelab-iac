resource "netbird_route" "this" {
  for_each = var.routes

  network_id            = each.value.network_id
  description           = each.value.description
  enabled               = each.value.enabled
  network               = each.value.network
  domains               = each.value.domains
  metric                = each.value.metric
  masquerade            = each.value.masquerade
  peer                  = each.value.peer
  peer_groups           = [for g in each.value.peer_groups : var.group_ids[g]]
  groups                = [for g in each.value.groups : var.group_ids[g]]
  access_control_groups = [for g in each.value.access_control_groups : var.group_ids[g]]
}
