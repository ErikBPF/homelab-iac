# Root Terragrunt config for the GitHub component. Units under github/<stack>/
# include this. Generates the integrations/github provider + local encrypted
# state on the shared MinIO S3 backend.
#
# Auth: the provider reads GITHUB_TOKEN (a fine-grained or classic PAT for the
# owning account) and GITHUB_OWNER from the shell (.env via dotenv) — nothing
# secret on disk or in state-in-git. The token needs, per repo: Administration
# (read/write) for repo settings + workflow permissions, and Actions
# (read/write). For classic PATs the `repo` scope covers this.

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
    variable "github_token" {
      type      = string
      sensitive = true
    }

    variable "github_owner" {
      type = string
    }

    provider "github" {
      token = var.github_token
      owner = var.github_owner
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

  github_token = get_env("GITHUB_TOKEN")
  github_owner = get_env("GITHUB_OWNER", "ErikBPF")
}
