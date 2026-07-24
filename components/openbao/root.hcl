generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "vault_role_id" {
      type      = string
      sensitive = true
    }
    variable "vault_secret_id" {
      type      = string
      sensitive = true
      ephemeral = true
    }
    variable "vault_token" {
      type      = string
      sensitive = true
      ephemeral = true
      default   = ""
    }
    provider "vault" {
      address          = "https://openbao.homelab.pastelariadev.com"
      skip_child_token = true
      token             = var.vault_token != "" ? var.vault_token : null
      dynamic "auth_login" {
        for_each = var.vault_token == "" ? [1] : []
        content {
          path = "auth/approle/login"
          parameters = {
            role_id   = var.vault_role_id
            secret_id = var.vault_secret_id
          }
        }
      }
    }
  EOT
}

inputs = {
  vault_role_id   = get_env("VAULT_ROLE_ID")
  vault_secret_id = get_env("VAULT_SECRET_ID")
  vault_token     = get_env("VAULT_TOKEN", "")
}
