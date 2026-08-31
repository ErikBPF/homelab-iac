data "authentik_group" "readers" {
  name          = var.reader_group_name
  include_users = false
}
data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-explicit-consent"
}

data "authentik_flow" "authentication" {
  slug = "default-authentication-flow"
}

data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_certificate_key_pair" "signing" {
  name              = "authentik Self-signed Certificate"
  fetch_certificate = false
  fetch_key         = false
}

data "authentik_property_mapping_provider_scope" "defaults" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-offline_access",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
  ]
}

resource "authentik_property_mapping_provider_scope" "groups" {
  name       = "Harbor groups"
  scope_name = "groups"
  expression = <<-EOT
    return {
      "groups": [
        group.name
        for group in request.user.ak_groups.all()
        if group.name.startswith("harbor-")
      ],
    }
  EOT
}

resource "authentik_provider_oauth2" "harbor" {
  name                = "Harbor"
  client_id           = "harbor"
  client_type         = "confidential"
  grant_types         = ["authorization_code", "refresh_token"]
  authorization_flow  = data.authentik_flow.authorization.id
  authentication_flow = data.authentik_flow.authentication.id
  invalidation_flow   = data.authentik_flow.invalidation.id
  allowed_redirect_uris = [{
    matching_mode = "strict"
    url           = "https://harbor.homelab.pastelariadev.com/c/oidc/callback/"
  }]
  access_code_validity   = "minutes=1"
  access_token_validity  = "minutes=5"
  refresh_token_validity = "hours=8"
  issuer_mode            = "per_provider"
  signing_key            = data.authentik_certificate_key_pair.signing.id
  sub_mode               = "user_uuid"
  property_mappings = concat(
    data.authentik_property_mapping_provider_scope.defaults.ids,
    [authentik_property_mapping_provider_scope.groups.id],
  )
}

resource "authentik_application" "harbor" {
  name               = "Harbor"
  slug               = "harbor"
  protocol_provider  = authentik_provider_oauth2.harbor.id
  policy_engine_mode = "all"
}

resource "authentik_policy_binding" "harbor_readers" {
  target = authentik_application.harbor.uuid
  group  = data.authentik_group.readers.id
  order  = 0
}

resource "authentik_policy_expression" "mfa_enrolled" {
  name       = "Harbor MFA enrollment"
  expression = <<-EOT
    return (
      ak_user_has_authenticator(request.user, "totp") or
      ak_user_has_authenticator(request.user, "webauthn")
    )
  EOT
}

resource "authentik_policy_binding" "harbor_mfa" {
  target = authentik_application.harbor.uuid
  policy = authentik_policy_expression.mfa_enrolled.id
  order  = 10
}

resource "harbor_config_auth" "oidc" {
  auth_mode         = "oidc_auth"
  primary_auth_mode = false

  oidc_name                     = "Authentik"
  oidc_endpoint                 = "https://authentik.homelab.pastelariadev.com/application/o/harbor/"
  oidc_client_id                = authentik_provider_oauth2.harbor.client_id
  oidc_client_secret_wo         = authentik_provider_oauth2.harbor.client_secret
  oidc_client_secret_wo_version = 1
  oidc_scope                    = "openid,email,profile,offline_access,groups"
  oidc_verify_cert              = true
  oidc_auto_onboard             = true
  oidc_group_filter             = "harbor-*"
  oidc_groups_claim             = "groups"
  oidc_user_claim               = "preferred_username"
  oidc_logout                   = true
}

data "harbor_project" "this" {
  for_each = var.projects
  name     = each.key
}

resource "harbor_project_member_group" "readers" {
  for_each = var.projects

  project_id = data.harbor_project.this[each.key].id
  group_name = var.reader_group_name
  role       = "guest"
  type       = "oidc"

  depends_on = [harbor_config_auth.oidc]
}
