output "token_id" {
  description = "Cloudflare API token id (safe to expose; not the secret)."
  value       = cloudflare_api_token.this.id
}

output "token_value" {
  description = <<-EOT
    The secret token value — only ever returned at create time, stored in the
    repo's encrypted state. Bridge it to SWAG on discovery:
      terragrunt output -raw token_value
      → set it as the SWAG cloudflare token var in servarr's .env.sops
      → just push-env discovery
      → recreate swag letting swag-init run (RUNBOOK; never --no-deps)
  EOT
  value       = cloudflare_api_token.this.value
  sensitive   = true
}
