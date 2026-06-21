# Shared OpenTofu S3-backend (MinIO on discovery via SWAG) config for every
# component. Each component's root.hcl reads this and merges its own per-unit
# `key`, so a backend change touches one file instead of four. State is still
# OpenTofu-encrypted on top — MinIO only ever stores ciphertext.
# access_key/secret_key come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
locals {
  s3 = {
    bucket    = "tofu-state"
    endpoints = { s3 = "https://minio-tfstate.homelab.pastelariadev.com" }
    region    = "us-east-1"

    use_path_style              = true
    use_lockfile                = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
  }
}
