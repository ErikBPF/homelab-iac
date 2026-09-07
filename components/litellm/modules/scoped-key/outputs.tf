output "key" {
  value     = litellm_key.this.generated_key
  sensitive = true
}
