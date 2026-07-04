output "service_token_client_id" {
  description = "CF-Access-Client-Id header value for the device (safe to embed)."
  value       = cloudflare_zero_trust_access_service_token.device.client_id
}

output "service_token_client_secret" {
  description = <<-EOT
    CF-Access-Client-Secret header value for the device. Only knowable at
    creation; lives in this repo's encrypted state. Read once and paste into
    the device secrets.h (CF_ACCESS_CLIENT_SECRET):
      terragrunt output -raw service_token_client_secret
  EOT
  value       = cloudflare_zero_trust_access_service_token.device.client_secret
  sensitive   = true
}
