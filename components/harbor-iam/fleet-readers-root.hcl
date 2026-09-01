generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "harbor_bootstrap_admin_username" {
      type      = string
      sensitive = true
      ephemeral = true
    }
    variable "harbor_bootstrap_admin_password" {
      type      = string
      sensitive = true
      ephemeral = true
    }
    variable "vault_role_id" {
      type      = string
      sensitive = true
    }
    variable "vault_secret_id" {
      type      = string
      sensitive = true
      ephemeral = true
    }

    provider "harbor" {
      url      = "https://harbor.homelab.pastelariadev.com"
      username = var.harbor_bootstrap_admin_username
      password = var.harbor_bootstrap_admin_password
      insecure = false
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
  harbor_bootstrap_admin_username = get_env("HARBOR_BOOTSTRAP_ADMIN_USERNAME", "admin")
  harbor_bootstrap_admin_password = get_env("HARBOR_BOOTSTRAP_ADMIN_PASSWORD")
  vault_role_id                   = get_env("OPENBAO_HARBOR_FLEET_READERS_PUBLISHER_ROLE_ID")
  vault_secret_id                 = get_env("OPENBAO_HARBOR_FLEET_READERS_PUBLISHER_SECRET_ID")
}
