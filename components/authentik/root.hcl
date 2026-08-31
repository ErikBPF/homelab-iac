generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "authentik_token" {
      type      = string
      sensitive = true
      ephemeral = true
    }

    provider "authentik" {
      url      = "https://authentik.homelab.pastelariadev.com"
      token    = var.authentik_token
      insecure = false
    }
  EOT
}

inputs = {
  authentik_token = get_env("AUTHENTIK_TOKEN")
}
