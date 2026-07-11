output "setup_key_ids" {
  description = "Map of setup-key name -> NetBird setup-key ID."
  value       = { for k, v in netbird_setup_key.this : k => v.id }
}

# The plaintext key is only ever visible via the API/state, never re-shown by
# the dashboard after creation. Sensitive — never pipe this into a non-sensitive
# output, a log, or anything that lands outside this repo's encrypted state.
output "setup_keys" {
  description = "Map of setup-key name -> plaintext key. SENSITIVE."
  value       = { for k, v in netbird_setup_key.this : k => v.key }
  sensitive   = true
}
