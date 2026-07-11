resource "netbird_policy" "this" {
  for_each = var.policies

  name                  = each.key
  description           = each.value.description
  enabled               = each.value.enabled
  source_posture_checks = [for pc in each.value.source_posture_checks : var.posture_check_ids[pc]]

  dynamic "rule" {
    for_each = each.value.rules
    content {
      name          = rule.value.name
      description   = rule.value.description
      enabled       = rule.value.enabled
      action        = rule.value.action
      protocol      = rule.value.protocol
      bidirectional = rule.value.bidirectional
      sources       = [for g in rule.value.sources : var.group_ids[g]]
      destinations  = [for g in rule.value.destinations : var.group_ids[g]]
      ports         = rule.value.ports
    }
  }
}
