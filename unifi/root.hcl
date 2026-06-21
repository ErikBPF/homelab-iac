# Root Terragrunt config. Every live unit under environments/<env>/<stack>/
# includes this file. It:
#   - reads per-env settings (env.hcl) + shared flags (default_flags.hcl)
#   - generates the UniFi provider config into each unit
#   - wires local state, one file per env/stack
#   - injects the per-env API key from the shell (.env) as a sensitive input
#
# The api_key is passed via `inputs` (-> TF_VAR_unifi_api_key), so it lives only
# in the process env, never written to a .tf file or state-in-git.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  flags    = read_terragrunt_config(find_in_parent_folders("default_flags.hcl"))

  env     = local.env_vars.locals.env
  api_url = local.env_vars.locals.api_url
  site    = local.env_vars.locals.site

  allow_insecure = local.flags.locals.allow_insecure

  # From .env (dotenv): UNIFI_API_KEY_home / UNIFI_API_KEY_lab / ...
  api_key = get_env("UNIFI_API_KEY_${local.env}")

  backend = read_terragrunt_config(find_in_parent_folders("backend.hcl"))
}

# Local state, one file per env/stack, kept out of git (.gitignore: unifi/.state/).
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

# required_providers lives in each module's versions.tf (the module is the root
# module once Terragrunt sources it). We only generate the provider config here.
generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "unifi_api_url" {
      type = string
    }
    variable "unifi_api_key" {
      type      = string
      sensitive = true
    }
    variable "unifi_site" {
      type    = string
      default = "default"
    }
    variable "unifi_insecure" {
      type    = bool
      default = true
    }

    provider "unifi" {
      api_url        = var.unifi_api_url
      api_key        = var.unifi_api_key
      site           = var.unifi_site
      allow_insecure = var.unifi_insecure
    }
  EOT
}

# OpenTofu native state + plan encryption (AES-GCM, PBKDF2 passphrase from .env).
# Keeps WLAN passphrases and imported data encrypted at rest in local state.
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
  unifi_api_url    = local.api_url
  unifi_api_key    = local.api_key
  unifi_site       = local.site
  unifi_insecure   = local.allow_insecure
  state_passphrase = get_env("UNIFI_STATE_PASSPHRASE")
}
