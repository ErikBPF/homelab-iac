# Root Terragrunt config for the Cloudflare component. Units under
# cloudflare/<stack>/ include this. Generates the cloudflare provider + local
# encrypted state.
#
# Auth: the provider reads CLOUDFLARE_API_TOKEN from the shell (.env via dotenv)
# — nothing secret on disk or in state-in-git.

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
    # MinIO on discovery via SWAG. State is still OpenTofu-encrypted on top, so
    # MinIO only ever stores ciphertext. Component prefix avoids key collisions
    # in the shared bucket (e.g. cloudflare/dns vs tailscale/dns).
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
    # access_key/secret_key from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (env).
  }
}

generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "cf_api_token" {
      type      = string
      sensitive = true
    }

    provider "cloudflare" {
      api_token = var.cf_api_token
    }
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

  # Single dual-scope token (Zone:DNS:Edit + Account:Tunnel:Edit) for all units.
  cf_api_token = get_env("CLOUDFLARE_API_TOKEN")
}
