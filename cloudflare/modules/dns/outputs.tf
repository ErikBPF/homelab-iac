output "record_ids" {
  description = "Map of FQDN -> Cloudflare record id."
  value       = { for k, v in cloudflare_record.this : k => v.id }
}
