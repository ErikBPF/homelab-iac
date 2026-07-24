output "key" {
  value     = litellm_key.rotation.generated_key
  sensitive = true
}
