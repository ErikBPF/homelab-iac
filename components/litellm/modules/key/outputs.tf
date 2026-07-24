output "key" {
  value     = litellm_key.rotation.key
  sensitive = true
}
