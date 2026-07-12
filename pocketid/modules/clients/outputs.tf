output "client_ids" {
  description = "Map of client display name -> PocketID client ID."
  value       = { for k, c in pocketid_client.this : k => c.id }
}

output "client_secrets" {
  description = "Map of client display name -> client secret. Empty for public+PKCE clients (NetBird); present only for confidential clients."
  value       = { for k, c in pocketid_client.this : k => c.client_secret }
  sensitive   = true
}
