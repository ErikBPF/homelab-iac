generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "harbor_project_iam_manager_username" {
      type      = string
      sensitive = true
      ephemeral = true
    }
    variable "harbor_project_iam_manager_secret" {
      type      = string
      sensitive = true
      ephemeral = true
    }

    provider "harbor" {
      url      = "https://harbor.homelab.pastelariadev.com"
      username = var.harbor_project_iam_manager_username
      password = var.harbor_project_iam_manager_secret
      insecure = false
    }
  EOT
}

inputs = {
  harbor_project_iam_manager_username = get_env("HARBOR_PROJECT_IAM_MANAGER_USERNAME", "robot$homelab-iac-harbor-project-iam-manager")
  harbor_project_iam_manager_secret   = get_env("HARBOR_PROJECT_IAM_MANAGER_SECRET")
}
