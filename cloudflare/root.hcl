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
  backend = "local"
  generate = {
    path      = "backend_gen.tf"
    if_exists = "overwrite"
  }
  config = {
    path = "${get_parent_terragrunt_dir()}/.state/${path_relative_to_include()}/terraform.tfstate"
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
