generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "authentik_token" {
      type      = string
      sensitive = true
      ephemeral = true
    }
    variable "harbor_username" {
      type      = string
      sensitive = true
      ephemeral = true
    }
    variable "harbor_password" {
      type      = string
      sensitive = true
      ephemeral = true
    }

    provider "authentik" {
      url      = "https://authentik.homelab.pastelariadev.com"
      token    = var.authentik_token
      insecure = false
    }

    provider "harbor" {
      url      = "https://harbor.homelab.pastelariadev.com"
      username = var.harbor_username
      password = var.harbor_password
      insecure = false
    }
  EOT
}

inputs = {
  authentik_token = get_env("AUTHENTIK_TOKEN")
  harbor_username = get_env("HARBOR_USERNAME", "admin")
  harbor_password = get_env("HARBOR_PASSWORD")
}
