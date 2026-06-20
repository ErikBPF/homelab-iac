resource "cloudflare_record" "this" {
  for_each = var.records

  zone_id = var.zone_id
  # Cloudflare stores the short label; map keys are FQDNs for readability.
  name    = trimsuffix(each.key, ".${var.zone_name}")
  type    = each.value.type
  content = each.value.value
  proxied = each.value.proxied
  ttl     = each.value.ttl

  # allow_overwrite is a create-time flag absent from imported state (no-op).
  lifecycle {
    ignore_changes = [allow_overwrite]
  }
}
