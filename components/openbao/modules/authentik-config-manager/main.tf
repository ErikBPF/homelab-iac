resource "vault_kv_secret_v2" "credential" {
  mount = "secret"
  name  = "iac/authentik-config-manager"
  data_json_wo = jsonencode({
    AUTHENTIK_CONFIG_MANAGER_USERNAME = "svc-homelab-iac-authentik-config-manager"
    AUTHENTIK_CONFIG_MANAGER_TOKEN    = var.authentik_config_manager_token
  })
  # Increment for any future credential rotation; do not reissue during callback migration.
  data_json_wo_version = 1
}

resource "vault_policy" "reader" {
  name   = "svc-homelab-iac-openbao-authentik-config-manager-reader"
  policy = <<-EOT
    path "secret/data/iac/authentik-config-manager" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_approle_auth_backend_role" "reader" {
  backend        = "approle"
  role_name      = "svc-homelab-iac-openbao-authentik-config-manager-reader"
  bind_secret_id = true
  token_policies = [vault_policy.reader.name]
  token_ttl      = 300
  token_max_ttl  = 300
  secret_id_ttl  = 7776000
  token_type     = "default"
}
