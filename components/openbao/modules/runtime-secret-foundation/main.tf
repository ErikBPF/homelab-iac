resource "vault_mount" "secret" {
  path = "secret"
  type = "kv"
  options = {
    version = "2"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_auth_backend" "approle" {
  path = "approle"
  type = "approle"

  lifecycle {
    prevent_destroy = true
  }
}

resource "vault_policy" "home_read" {
  name   = "home-read"
  policy = <<-EOT
    path "secret/data/home/*" {
      capabilities = ["read"]
    }
    path "secret/metadata/home/*" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_policy" "iac_writer" {
  name = "homelab-iac-ha-harness"
  policy = join("\n", [
    "path \"secret/data/home/ha-harness-litellm\" { capabilities = [\"create\", \"update\", \"read\"] }",
    "path \"secret/metadata/home/ha-harness-litellm\" { capabilities = [\"read\"] }",
  ])
}

resource "vault_approle_auth_backend_role" "vault_agent" {
  backend        = vault_auth_backend.approle.path
  role_name      = "vault-agent"
  bind_secret_id = true
  token_policies = ["discord-read", "home-read", "kindle-release-read"]
  token_ttl      = 3600
  token_max_ttl  = 14400
  token_type     = "default"
}

resource "vault_approle_auth_backend_role" "iac_writer" {
  backend        = vault_auth_backend.approle.path
  role_name      = "homelab-iac-ha-harness"
  bind_secret_id = true
  token_policies = ["homelab-iac-ha-harness"]
  token_ttl      = 3600
  token_max_ttl  = 14400
  token_type     = "default"
}
