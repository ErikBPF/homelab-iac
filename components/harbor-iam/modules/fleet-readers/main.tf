ephemeral "random_password" "reader" {
  for_each         = var.fleet_hosts
  length           = 32
  special          = true
  override_special = "_-"
}

resource "harbor_robot_account" "reader" {
  for_each = var.fleet_hosts

  name        = "desktop-nixos-${each.key}-harbor-reader"
  description = "Pull-only fleet identity for ${each.key}"
  level       = "system"
  duration    = 365
  disable     = contains(var.disabled_hosts, each.key)

  secret_wo         = tostring(ephemeral.random_password.reader[each.key].result)
  secret_wo_version = var.rotation_generation

  permissions {
    kind      = "project"
    namespace = "*"
    access {
      action   = "pull"
      resource = "repository"
    }
  }
}

resource "vault_kv_secret_v2" "reader" {
  for_each = var.fleet_hosts

  mount = "secret"
  name  = "fleet/harbor/readers/${each.key}"
  data_json_wo = jsonencode({
    HARBOR_READER_USERNAME = harbor_robot_account.reader[each.key].full_name
    HARBOR_READER_SECRET   = tostring(ephemeral.random_password.reader[each.key].result)
  })
  data_json_wo_version = var.rotation_generation
}

ephemeral "random_password" "cognee_publisher" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "harbor_robot_account" "cognee_publisher" {
  name        = "cognee-homelab-publisher"
  description = "Library-only publisher for signed Cognee releases"
  level       = "project"
  duration    = 365

  secret_wo         = tostring(ephemeral.random_password.cognee_publisher.result)
  secret_wo_version = var.rotation_generation

  permissions {
    kind      = "project"
    namespace = "library"
    access {
      action   = "pull"
      resource = "repository"
    }
    access {
      action   = "push"
      resource = "repository"
    }
  }
}

resource "vault_kv_secret_v2" "cognee_publisher" {
  mount = "secret"
  name  = "home/cognee-harbor-publisher"
  data_json_wo = jsonencode({
    HARBOR_PUBLISHER_USERNAME = harbor_robot_account.cognee_publisher.full_name
    HARBOR_PUBLISHER_SECRET   = tostring(ephemeral.random_password.cognee_publisher.result)
  })
  data_json_wo_version = var.rotation_generation
}
