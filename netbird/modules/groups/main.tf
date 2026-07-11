resource "netbird_group" "this" {
  for_each = var.groups

  name      = each.key
  peers     = each.value.peers
  resources = each.value.resources
}
