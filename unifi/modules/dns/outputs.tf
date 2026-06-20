output "record_ids" {
  description = "Map of record name -> UniFi DNS record id."
  value       = { for k, v in unifi_dns_record.this : k => v.id }
}
