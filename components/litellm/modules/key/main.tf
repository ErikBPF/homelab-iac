resource "litellm_key" "this" {
  key                   = var.key
  key_alias             = var.key_alias
  models                = var.models
  max_parallel_requests = var.max_parallel_requests
  rpm_limit             = var.rpm_limit
  tpm_limit             = var.tpm_limit
  metadata              = var.metadata
}
