resource "netbird_setup_key" "this" {
  for_each = var.setup_keys

  name           = each.key
  type           = each.value.type
  expiry_seconds = each.value.expiry_seconds
  usage_limit    = each.value.usage_limit
  ephemeral      = each.value.ephemeral
  auto_groups    = [for g in each.value.auto_groups : var.group_ids[g]]
}
