data "authentik_user" "service_account" {
  username = var.service_account_username
}

resource "authentik_user" "operator" {
  username = var.operator_username
  name     = var.operator_username
}

resource "authentik_group" "readers" {
  name         = var.reader_group_name
  is_superuser = false
  users        = [authentik_user.operator.id]
}

resource "authentik_rbac_role" "iac" {
  name = "rbac-homelab-iac-authentik-config-manager"
}

resource "authentik_rbac_permission_role" "iac" {
  for_each = var.permissions

  role       = authentik_rbac_role.iac.id
  permission = each.value
}

resource "authentik_group" "iac" {
  name         = "rbac-homelab-iac-authentik-config-manager"
  is_superuser = false
  users        = [data.authentik_user.service_account.id]
  roles        = [authentik_rbac_role.iac.id]

  lifecycle {
    precondition {
      condition = (
        contains(["service_account", "internal_service_account"], data.authentik_user.service_account.type) &&
        !data.authentik_user.service_account.is_superuser
      )
      error_message = "Authentik config manager must be a non-superuser service account."
    }
  }
}
