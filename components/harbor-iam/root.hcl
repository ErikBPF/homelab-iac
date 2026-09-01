generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "authentik_config_manager_token" {
      type      = string
      sensitive = true
      ephemeral = true
    }
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
    variable "harbor_project_iam_manager_secret" {
      type      = string
      sensitive = true
      ephemeral = true
    }
    variable "harbor_project_iam_manager_secret_configured" {
      type = bool
    }
    variable "harbor_project_iam_manager_existing" {
      type = bool
    }

    provider "authentik" {
      url      = "https://authentik.homelab.pastelariadev.com"
      token    = var.authentik_config_manager_token
      insecure = false
    }

    provider "harbor" {
      url      = "https://harbor.homelab.pastelariadev.com"
      username = var.harbor_bootstrap_admin_username
      password = var.harbor_bootstrap_admin_password
      insecure = false
    }
  EOT
}

inputs = {
  authentik_config_manager_token               = get_env("AUTHENTIK_CONFIG_MANAGER_TOKEN")
  harbor_bootstrap_admin_username              = get_env("HARBOR_BOOTSTRAP_ADMIN_USERNAME", "admin")
  harbor_bootstrap_admin_password              = get_env("HARBOR_BOOTSTRAP_ADMIN_PASSWORD")
  harbor_project_iam_manager_secret            = get_env("HARBOR_PROJECT_IAM_MANAGER_SECRET", "")
  harbor_project_iam_manager_secret_configured = get_env("HARBOR_PROJECT_IAM_MANAGER_SECRET", "") != ""
  harbor_project_iam_manager_existing          = get_env("HARBOR_PROJECT_IAM_MANAGER_EXISTING", "false") == "true"
}
