output "service_token_client_ids" {
  description = "CF-Access-Client-Id per app (safe to embed), keyed by app name."
  value       = { for k, t in cloudflare_zero_trust_access_service_token.device : k => t.client_id }
}

output "service_token_client_secrets" {
  description = <<-EOT
    CF-Access-Client-Secret per app, keyed by app name. Only knowable at
    creation; lives in this repo's encrypted state. Read once and paste into the
    consumer's secret store, e.g. for the device:
      terragrunt output -json service_token_client_secrets | jq -r '."cosmo-whisper"'
  EOT
  value       = { for k, t in cloudflare_zero_trust_access_service_token.device : k => t.client_secret }
  sensitive   = true
}
