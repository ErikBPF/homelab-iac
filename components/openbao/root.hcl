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
    provider "vault" {
      address          = "https://openbao.homelab.pastelariadev.com"
      skip_child_token = true
      auth_login {
        path = "auth/approle/login"
        parameters = {
          role_id   = var.vault_role_id
          secret_id = var.vault_secret_id
        }
      }
    }
  EOT
}

inputs = {
  vault_role_id   = get_env("VAULT_ROLE_ID")
  vault_secret_id = get_env("VAULT_SECRET_ID")
}
