output "tunnel_tokens" {
  description = <<-EOT
    Per-tunnel connector tokens (the value cloudflared consumes as
    CLOUDFLARE_TUNNEL_TOKEN), keyed by tunnel name. Lives in the repo's
    encrypted state. Bridge each to its consumer:
      terragrunt output -json tunnel_tokens | jq -r '."<name>"'
      → write to OpenBao secret/data/home/tunneling CLOUDFLARE_TUNNEL_TOKEN
      → vault-agent re-renders /run/vault-agent/tunneling.env on discovery
      → just kick-stack discovery tunneling  (cloudflared reads env at start)
  EOT
  value = {
    for k, t in cloudflare_zero_trust_tunnel_cloudflared.this :
    k => t.tunnel_token
  }
  sensitive = true
}
