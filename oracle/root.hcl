# Root Terragrunt config for the Oracle Cloud (OCI) component. Units under
# oracle/<stack>/ include this. Generates the oci provider + local encrypted
# state, mirroring the other components in this repo.
#
# Auth: the provider reads OCI API-signing-key values from the shell (.env via
# dotenv, decrypted from .env.sops) — nothing secret on disk or in state-in-git.
# Required env vars (see .env.example): OCI_tenancy_ocid, OCI_user_ocid,
# OCI_fingerprint, OCI_private_key, OCI_region.

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
    variable "oci_tenancy_ocid" { type = string }
    variable "oci_user_ocid" { type = string }
    variable "oci_fingerprint" { type = string }
    variable "oci_private_key_b64" {
      type      = string
      sensitive = true
    }
    variable "oci_region" { type = string }

    provider "oci" {
      tenancy_ocid = var.oci_tenancy_ocid
      user_ocid    = var.oci_user_ocid
      fingerprint  = var.oci_fingerprint
      # PEM is kept base64-encoded in .env.sops (single-line, no multiline pain).
      private_key = base64decode(var.oci_private_key_b64)
      region      = var.oci_region
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

  # OCI API signing-key creds, sourced from the shell (.env / .env.sops).
  oci_tenancy_ocid    = get_env("OCI_tenancy_ocid")
  oci_user_ocid       = get_env("OCI_user_ocid")
  oci_fingerprint     = get_env("OCI_fingerprint")
  oci_private_key_b64 = get_env("OCI_private_key_b64")
  oci_region          = get_env("OCI_region")
}
