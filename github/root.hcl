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

    variable "github_app_id" {
      type    = string
      default = ""
    }

    variable "github_app_installation_id" {
      type    = string
      default = ""
    }

    variable "github_app_pem_file" {
      type      = string
      sensitive = true
      default   = ""
    }

    provider "github" {
      token = var.github_token
      owner = var.github_owner
    }

    # Installation-scoped resources (github_app_installation_repository) need app
    # auth: the provider mints short-lived installation tokens from the app id,
    # installation id and private key, so nothing here depends on an OAuth refresh
    # token that expires after eight hours.
    provider "github" {
      alias = "app_management"
      owner = var.github_owner

      app_auth {
        id              = var.github_app_id
        installation_id = var.github_app_installation_id
        pem_file        = var.github_app_pem_file
      }
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
        key_provider "pbkdf2" "current" {
          passphrase = var.state_passphrase
        }
        method "aes_gcm" "current" {
          keys = key_provider.pbkdf2.current
        }
        state {
          method = method.aes_gcm.current
        }
        plan {
          method = method.aes_gcm.current
        }
      }
    }
  EOT
}

inputs = {
  state_passphrase = local.state_passphrase

  github_token                = get_env("GITHUB_TOKEN")
  github_owner                = get_env("GITHUB_OWNER", "ErikBPF")
  github_app_management_token = get_env("GITHUB_APP_MANAGEMENT_TOKEN", "")
}
