resource "adguardhome_rewrite" "this" {
  for_each = var.rewrites

  domain = each.key
  answer = each.value
}

# Singleton — only one adguardhome_user_rules may exist.
resource "adguardhome_user_rules" "this" {
  rules = var.user_rules
}

resource "adguardhome_list_filter" "this" {
  for_each = var.list_filters

  name      = each.key
  url       = each.value.url
  enabled   = each.value.enabled
  whitelist = each.value.whitelist
}
