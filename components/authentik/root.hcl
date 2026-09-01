generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "authentik_bootstrap_admin_token" {
      type      = string
      sensitive = true
      ephemeral = true
    }

    provider "authentik" {
      url      = "https://authentik.homelab.pastelariadev.com"
      token    = var.authentik_bootstrap_admin_token
      insecure = false
    }
  EOT
}

inputs = {
  authentik_bootstrap_admin_token = get_env("AUTHENTIK_BOOTSTRAP_ADMIN_TOKEN")
}
