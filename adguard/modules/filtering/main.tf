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

# Temporary state-address migration. Remove after the v0.1.7 rollout reaches a
# second no-op plan.
moved {
  from = adguard_rewrite.this["*.k8s.pastelariadev.com"]
  to   = adguardhome_rewrite.this["*.k8s.pastelariadev.com"]
}

moved {
  from = adguard_rewrite.this["k8s.pastelariadev.com"]
  to   = adguardhome_rewrite.this["k8s.pastelariadev.com"]
}

moved {
  from = adguard_rewrite.this["*.homelab.pastelariadev.com"]
  to   = adguardhome_rewrite.this["*.homelab.pastelariadev.com"]
}

moved {
  from = adguard_rewrite.this["homelab.pastelariadev.com"]
  to   = adguardhome_rewrite.this["homelab.pastelariadev.com"]
}

moved {
  from = adguard_rewrite.this["ha.pastelariadev.com"]
  to   = adguardhome_rewrite.this["ha.pastelariadev.com"]
}

moved {
  from = adguard_user_rules.this
  to   = adguardhome_user_rules.this
}

moved {
  from = adguard_list_filter.this["AdGuard DNS filter"]
  to   = adguardhome_list_filter.this["AdGuard DNS filter"]
}

moved {
  from = adguard_list_filter.this["AdAway Default Blocklist"]
  to   = adguardhome_list_filter.this["AdAway Default Blocklist"]
}

moved {
  from = adguard_list_filter.this["HaGeZi Multi Pro++"]
  to   = adguardhome_list_filter.this["HaGeZi Multi Pro++"]
}

moved {
  from = adguard_list_filter.this["OISD Big"]
  to   = adguardhome_list_filter.this["OISD Big"]
}

moved {
  from = adguard_list_filter.this["HaGeZi Threat Intelligence Feeds"]
  to   = adguardhome_list_filter.this["HaGeZi Threat Intelligence Feeds"]
}
