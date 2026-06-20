resource "unifi_dns_record" "this" {
  for_each = var.records

  name    = each.key
  type    = each.value.type
  record  = each.value.record
  enabled = each.value.enabled
  ttl     = each.value.ttl
}
