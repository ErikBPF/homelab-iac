# The tunnel itself (connector credential) + its ingress config. Owning the
# `cloudflare_zero_trust_tunnel_cloudflared` resource brings the tunnel's ingress
# config under Terraform. `secret` is write-only: on import the provider returns
# it empty, so any non-empty HCL value (the placeholder) is seen as a change that
# FORCES REPLACEMENT — which would mint a new tunnel id/token and break the live
# connector. `ignore_changes = [secret]` adopts the imported tunnel without
# rotating it; the existing connector token stays valid (already in Vault).
# To deliberately rotate, remove the ignore and set a real 32-byte base64 secret.
resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  for_each = var.tunnels

  account_id = var.account_id
  name       = each.key
  secret     = each.value.secret

  lifecycle {
    ignore_changes = [secret]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  for_each = var.tunnels

  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this[each.key].id

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
