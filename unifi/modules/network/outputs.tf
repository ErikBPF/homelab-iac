output "network_ids" {
  description = "Map of network name -> UniFi network id."
  value       = { for k, v in unifi_network.this : k => v.id }
}
