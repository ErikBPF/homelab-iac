resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  for_each = var.tunnels

  account_id = var.account_id
  tunnel_id  = each.value.tunnel_id

  config {
    dynamic "ingress_rule" {
      for_each = each.value.ingress
      content {
        hostname = ingress_rule.value.hostname
        path     = ingress_rule.value.path
        service  = ingress_rule.value.service
      }
    }
  }
}
