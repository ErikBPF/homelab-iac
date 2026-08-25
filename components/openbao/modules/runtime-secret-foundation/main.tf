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

resource "vault_policy" "github_app_management" {
  name   = "github-app-management"
  policy = <<-EOT
    path "secret/data/home/github-app-management" {
      capabilities = ["read", "patch"]
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

resource "vault_policy" "eso" {
  name   = "eso"
  policy = <<-EOT
    path "secret/data/lab/*" {
      capabilities = ["read"]
    }
    path "secret/metadata/lab/*" {
      capabilities = ["read", "list"]
    }
    path "secret/data/shared/*" {
      capabilities = ["read"]
    }
  EOT
}

locals {
  gitops_eso_lanes = {
    platform      = "platform/*"
    homelab       = "lab/*"
    home-services = "home-services/*"
  }
}

resource "vault_policy" "gitops_lane" {
  for_each = local.gitops_eso_lanes
  name     = "eso-${each.key}"
  policy   = <<-EOT
    path "secret/data/${each.value}" {
      capabilities = ["read"]
    }
    path "secret/metadata/${each.value}" {
      capabilities = ["read", "list"]
    }
  EOT
}

resource "vault_policy" "wazuh_agent" {
  name   = "wazuh-agent"
  policy = <<-EOT
    path "secret/data/platform/wazuh/wazuh-authd-pass" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_approle_auth_backend_role" "vault_agent" {
  backend        = vault_auth_backend.approle.path
  role_name      = "vault-agent"
  bind_secret_id = true
  token_policies = ["discord-read", "home-read", "kindle-release-read", "github-app-management"]
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

resource "vault_approle_auth_backend_role" "eso" {
  backend        = vault_auth_backend.approle.path
  role_name      = "eso"
  bind_secret_id = true
  token_policies = ["eso"]
  token_ttl      = 1200
  token_max_ttl  = 3600
  token_type     = "default"
}

resource "vault_approle_auth_backend_role" "gitops_lane" {
  for_each       = local.gitops_eso_lanes
  backend        = vault_auth_backend.approle.path
  role_name      = "eso-${each.key}"
  bind_secret_id = true
  token_policies = [vault_policy.gitops_lane[each.key].name]
  token_ttl      = 1200
  token_max_ttl  = 3600
  token_type     = "default"
}

resource "vault_approle_auth_backend_role" "wazuh_agent" {
  backend        = vault_auth_backend.approle.path
  role_name      = "wazuh-agent"
  bind_secret_id = true
  token_policies = [vault_policy.wazuh_agent.name]
  token_ttl      = 3600
  token_max_ttl  = 14400
  token_type     = "default"
}
