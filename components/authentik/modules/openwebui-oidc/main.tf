# Adopt the existing provider only; keep its application, client secret and bindings.
data "authentik_provider_oauth2_config" "existing" {
  provider_id = 3
}

resource "authentik_provider_oauth2" "openwebui" {
  name               = "openwebui"
  client_id          = data.authentik_provider_oauth2_config.existing.client_id
  client_type        = "confidential"
  authorization_flow = "fa6bb8c8-e664-458d-89ec-c4c80a4d01f6"
  invalidation_flow  = "d5a6979b-4d73-474e-958b-4885f5cd948d"

  allowed_redirect_uris = [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://openwebui.homelab.pastelariadev.com/oauth/oidc/callback"
    },
    # Temporary compatibility callback; remove after the HTTPS consumer is verified.
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "http://openwebui.homelab.pastelariadev.com/oauth/oidc/callback"
    },
  ]

  access_code_validity       = "minutes=1"
  access_token_validity      = "hours=1"
  refresh_token_validity     = "days=30"
  refresh_token_threshold    = "seconds=0"
  issuer_mode                = "per_provider"
  sub_mode                   = "hashed_user_id"
  include_claims_in_id_token = true
  logout_method              = "backchannel"
  logout_uri                 = ""
  signing_key                = "a2f6e3ea-c944-4328-8ffd-e0a2b2beb529"
  grant_types                = []
  jwt_federation_providers   = []
  jwt_federation_sources     = []
  property_mappings = [
    "4d038866-aa28-420e-9086-bbb9254fb485",
    "5e30d09e-9480-4ef9-bb88-73dc672c43cc",
    "0fcd1afb-4e2f-4534-b6d7-f071513aeaa5",
  ]

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = authentik_provider_oauth2.openwebui
  id = "3"
}
