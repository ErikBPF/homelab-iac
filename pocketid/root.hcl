# Root Terragrunt config for the PocketID component. Units under
# pocketid/<stack>/ include this. Generates the pocketid provider + local
# encrypted state, mirroring netbird/root.hcl and tailscale/root.hcl.
#
# Auth: the provider reads POCKETID_BASE_URL + POCKETID_API_TOKEN from the shell
# (.env via dotenv, decrypted from .env.sops) — nothing secret on disk or in
# state-in-git, same pattern as the NetBird PAT (netbird/root.hcl) and the
# Tailscale OAuth creds (tailscale/root.hcl). Mint the API token in the PocketID
# admin UI (log into id.<zone> with the passkey -> Settings -> API Keys). It is a
# human op (Phase S, RFC 2026-07-11-netbird-terraform-declarative-admin.md
# §4/G3), not something this stack creates for itself. The PocketID admin UI
# WORKS — only the *netbird dashboard* SSO is broken — so the token is mintable.
#
# base_url points at the self-hosted PocketID on discovery, tailnet-only behind
# SWAG (RFC §5). `terragrunt apply` here must run from a device joined to the
# tailnet, on a wired LAN host (repo convention — a Wi-Fi apply can self-lock).
#
# Community/pre-1.0 provider risk: Trozz/pocketid is a community provider, so the
# version is pinned EXACTLY (not a range) in the module's versions.tf and
# .terraform.lock.hcl is committed per unit — same discipline as netbird's 0.0.9.

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
    variable "pocketid_base_url" {
      type = string
    }
    variable "pocketid_api_token" {
      type      = string
      sensitive = true
    }

    provider "pocketid" {
      base_url  = var.pocketid_base_url
      api_token = var.pocketid_api_token
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

  # From .env (dotenv), Phase-S human-minted (see header). base_url defaults to
  # the RFC's tailnet-only PocketID hostname; override via env if it changes.
  pocketid_base_url  = get_env("POCKETID_BASE_URL", "https://id.homelab.pastelariadev.com")
  pocketid_api_token = get_env("POCKETID_API_TOKEN")
}
