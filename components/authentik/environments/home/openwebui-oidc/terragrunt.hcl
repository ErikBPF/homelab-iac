include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

terraform {
  source = "${get_repo_root()}/components/authentik/modules//openwebui-oidc"
}

# Use the existing config manager; the component root is reserved for admin bootstrap.
generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "authentik_config_manager_token" {
      type      = string
      sensitive = true
      ephemeral = true
    }
    provider "authentik" {
      url      = "https://authentik.homelab.pastelariadev.com"
      token    = var.authentik_config_manager_token
      insecure = false
    }
  EOT
}

inputs = {
  authentik_config_manager_token = get_env("AUTHENTIK_CONFIG_MANAGER_TOKEN")
}
