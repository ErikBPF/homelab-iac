generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    variable "grafana_bootstrap_auth" {
      type      = string
      sensitive = true
      ephemeral = true
    }

    provider "grafana" {
      url                  = "https://grafana.homelab.pastelariadev.com"
      auth                 = var.grafana_bootstrap_auth
      org_id               = var.org_id
      insecure_skip_verify = false
    }
  EOT
}

inputs = {
  grafana_bootstrap_auth = get_env("GRAFANA_BOOTSTRAP_AUTH")
}
