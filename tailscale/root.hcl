# Root Terragrunt config for the Tailscale component. Units under
# tailscale/<stack>/ include this. Generates the tailscale provider + local
# encrypted state.
#
# Auth: the provider reads TAILSCALE_OAUTH_CLIENT_ID / _SECRET / TAILSCALE_TAILNET
# from the shell (.env via dotenv) — nothing secret on disk or in state-in-git.

locals {
  # Shared repo state-encryption passphrase (named UNIFI_* for historical
  # reasons; it encrypts all local state in this repo).
  state_passphrase = get_env("UNIFI_STATE_PASSPHRASE")
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend_gen.tf"
    if_exists = "overwrite"
  }
  config = {
    # MinIO on discovery via SWAG; state still OpenTofu-encrypted on top.
    # Component prefix avoids key collisions in the shared bucket.
    bucket    = "tofu-state"
    key       = "${basename(get_parent_terragrunt_dir())}/${path_relative_to_include()}/terraform.tfstate"
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

generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    provider "tailscale" {}
  EOT
}

generate "encryption" {
  path      = "encryption_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "state_passphrase" {
      type      = string
      sensitive = true
    }

    terraform {
      encryption {
        key_provider "pbkdf2" "k" {
          passphrase = var.state_passphrase
        }
        method "aes_gcm" "m" {
          keys = key_provider.pbkdf2.k
        }
        state {
          method = method.aes_gcm.m
        }
        plan {
          method = method.aes_gcm.m
        }
      }
    }
  EOT
}

inputs = {
  state_passphrase = local.state_passphrase
}
