resource "authentik_user" "reader" {
  username = "svc-aster-authentik-identity-reader"
  name     = "Aster current identity reader"
  type     = "service_account"
}

resource "authentik_rbac_role" "reader" {
  name = "rbac-aster-authentik-identity-reader"
}

resource "authentik_rbac_permission_role" "reader" {
  for_each = toset([
    "authentik_core.view_user",
    "authentik_core.view_group",
  ])

  role       = authentik_rbac_role.reader.id
  permission = each.value
}

resource "authentik_group" "reader" {
  name         = "rbac-aster-authentik-identity-reader"
  is_superuser = false
  users        = [authentik_user.reader.id]
  roles        = [authentik_rbac_role.reader.id]
}
