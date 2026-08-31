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
  name = "homelab-iac"
}

resource "authentik_rbac_permission_role" "iac" {
  for_each = var.permissions

  role       = authentik_rbac_role.iac.id
  permission = each.value
}

resource "authentik_group" "iac" {
  name         = "homelab-iac"
  is_superuser = false
  users        = [data.authentik_user.service_account.id]
  roles        = [authentik_rbac_role.iac.id]
}
