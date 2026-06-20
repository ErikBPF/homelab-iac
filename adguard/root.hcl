# Root Terragrunt config for the AdGuard Home component. Units under
# adguard/<stack>/ include this. Generates the adguard provider + local
# encrypted state.
#
# Auth: host/username/scheme are non-secret (below); the password comes from
# ADGUARD_PASSWORD in the shell (.env via dotenv) — never on disk or in state.
#
# OWNERSHIP (split): Terraform owns rewrites + user_rules + list_filters via the
# AdGuard API. The base config (DNS upstreams, dhcp, tls, querylog/stats) stays
# in servarr's AdGuardHome.yaml — the provider's adguard_config can't manage it
# cleanly (its update rejects the disabled-DHCP block). `just sync-servarr`
# excludes config/adguard/AdGuardHome.yaml so a sync can't clobber TF's changes.

locals {
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
    provider "adguard" {
      host     = "adguard.homelab.pastelariadev.com"
      username = "erik"
      scheme   = "https"
      # password from ADGUARD_PASSWORD env
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
}
