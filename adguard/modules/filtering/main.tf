resource "adguard_rewrite" "this" {
  for_each = var.rewrites

  domain = each.key
  answer = each.value
}

# Singleton — only one adguard_user_rules may exist.
resource "adguard_user_rules" "this" {
  rules = var.user_rules
}
