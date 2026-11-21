# Kepler's root backup controller reads only its Kubernetes scale credential.
# Runtime values and AppRole SecretIDs are provisioned outside Terraform state.
resource "vault_policy" "wazuh_kepler_reader" {
  name   = "svc-desktop-nixos-kepler-wazuh-manager-scale-reader"
  policy = <<-EOT
    path "secret/data/fleet/wazuh/manager-scale/kepler" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_approle_auth_backend_role" "wazuh_kepler_reader" {
  backend                 = vault_auth_backend.approle.path
  role_name               = "svc-desktop-nixos-kepler-wazuh-manager-scale-reader"
  bind_secret_id          = true
  token_policies          = [vault_policy.wazuh_kepler_reader.name]
  token_no_default_policy = true
  token_ttl               = 300
  token_max_ttl           = 300
  secret_id_ttl           = 7776000
  token_type              = "default"
}
