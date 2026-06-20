# Shared, non-secret flags read by the root terragrunt.hcl.
locals {
  # UDM / UniFiOS ships a self-signed TLS cert -> skip verification.
  allow_insecure = true
}
