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
  backend          = read_terragrunt_config(find_in_parent_folders("backend.hcl"))
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend_gen.tf"
    if_exists = "overwrite"
  }
  config = merge(local.backend.locals.s3, {
    key = "${basename(get_parent_terragrunt_dir())}/${path_relative_to_include()}/terraform.tfstate"
  })
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
        key_provider "pbkdf2" "primary" {
          passphrase = var.state_passphrase
        }
        method "aes_gcm" "primary" {
          keys = key_provider.pbkdf2.primary
        }
        state {
          method = method.aes_gcm.primary
        }
        plan {
          method = method.aes_gcm.primary
        }
      }
    }
  EOT
}

inputs = {
  state_passphrase = local.state_passphrase
}
