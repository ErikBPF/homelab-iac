# Root Terragrunt config for the NetBird component. Units under
# netbird/<stack>/ include this. Generates the netbird provider + local
# encrypted state, mirroring the other components in this repo.
#
# Auth: the provider reads an admin PAT from the shell (.env via dotenv,
# decrypted from .env.sops) — nothing secret on disk or in state-in-git, same
# pattern as the Tailscale OAuth creds (tailscale/root.hcl) and the Cloudflare
# API token (cloudflare/root.hcl). Mint the PAT in the NetBird dashboard
# (Settings -> Personal Access Tokens) after the control-plane bootstrap
# (desktop-nixos WP2); it is a human op (Phase S), not something this stack
# creates for itself.
#
# management_url points at the self-hosted control plane on discovery. Per
# the RFC (2026-07-10-netbird-selfhosted-overlay.md §5/§8) that endpoint is
# tailnet-only (no public reverse-proxy hostname) — `terragrunt apply` here
# must run from a device already joined to the tailnet, same constraint as
# reaching the dashboard in a browser.
#
# 0.x provider risk (RFC §8, grill #13): netbirdio/netbird is pre-1.0 and
# breaking changes can land on any point release, so the version is pinned
# EXACTLY (not a range) in every module's versions.tf, and .terraform.lock.hcl
# is committed per unit.

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
    variable "netbird_management_url" {
      type = string
    }
    variable "netbird_token" {
      type      = string
      sensitive = true
    }

    provider "netbird" {
      management_url = var.netbird_management_url
      token          = var.netbird_token
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

  # TODO(Phase S, human op): mint the admin PAT after control-plane bootstrap
  # (WP2) and store it as NETBIRD_TOKEN in .env.sops. NETBIRD_MANAGEMENT_URL
  # defaults to the RFC's tailnet-only hostname; override if it changes.
  netbird_management_url = get_env("NETBIRD_MANAGEMENT_URL", "https://nb.homelab.pastelariadev.com")
  netbird_token          = get_env("NETBIRD_TOKEN")
}
