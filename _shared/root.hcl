# Common Terragrunt plumbing for component units. Provider configuration stays
# in each component root; this file owns only backend and state encryption.

locals {
  state_passphrase = get_env("UNIFI_STATE_PASSPHRASE")
  backend          = read_terragrunt_config("${get_repo_root()}/backend.hcl")

  # This root lives under _shared/, so units are rendered as ../<component>/<unit>.
  # Strip only that shared-root hop to preserve the existing state object key.
  state_key = trimprefix(path_relative_to_include(), "../")
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend_gen.tf"
    if_exists = "overwrite"
  }
  config = merge(local.backend.locals.s3, {
    key = "${local.state_key}/terraform.tfstate"
  })
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
