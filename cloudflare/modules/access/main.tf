# Cloudflare Access edge for tunnel-exposed services, one entry per app. Per app,
# two ways in: a non-interactive service token (device — CF-Access-Client-Id/Secret
# headers, validated at the edge before the origin) and/or an email identity
# policy (human browser). New apps get hardened defaults; existing apps are
# reproduced by overriding attrs to their live values, then imported (adopted).
#
# NOTE: creating/adopting these needs an API token with Account > Access: Apps
# and Policies (+ Service Tokens) Edit — the shared dual-scope token cannot.

resource "cloudflare_zero_trust_access_application" "this" {
  for_each = var.applications

  account_id                 = var.account_id
  name                       = each.key
  domain                     = each.value.domain
  type                       = "self_hosted"
  session_duration           = each.value.session_duration
  app_launcher_visible       = each.value.app_launcher_visible
  auto_redirect_to_identity  = each.value.auto_redirect_to_identity
  http_only_cookie_attribute = each.value.http_only_cookie_attribute
  same_site_cookie_attribute = each.value.same_site_cookie_attribute
  enable_binding_cookie      = each.value.enable_binding_cookie
  skip_interstitial          = each.value.skip_interstitial
}

# Freshly-minted service token, only for apps that ask for one (create_service_token).
resource "cloudflare_zero_trust_access_service_token" "device" {
  for_each = { for k, v in var.applications : k => v if v.create_service_token }

  account_id = var.account_id
  name       = each.value.service_token_name
}

# Non-interactive policy: the app's own token (if any) + referenced existing tokens.
resource "cloudflare_zero_trust_access_policy" "service_token" {
  for_each = {
    for k, v in var.applications : k => v
    if v.create_service_token || length(v.extra_service_token_ids) > 0
  }

  account_id     = var.account_id
  application_id = cloudflare_zero_trust_access_application.this[each.key].id
  name           = each.value.token_policy_name
  precedence     = each.value.token_policy_precedence
  decision       = "non_identity"

  include {
    service_token = concat(
      each.value.create_service_token ? [cloudflare_zero_trust_access_service_token.device[each.key].id] : [],
      each.value.extra_service_token_ids,
    )
  }
}

# Interactive policy: allow-listed emails for a human browser.
resource "cloudflare_zero_trust_access_policy" "emails" {
  for_each = { for k, v in var.applications : k => v if length(v.allowed_emails) > 0 }

  account_id     = var.account_id
  application_id = cloudflare_zero_trust_access_application.this[each.key].id
  name           = each.value.email_policy_name
  precedence     = each.value.email_policy_precedence
  decision       = "allow"

  include {
    email = each.value.allowed_emails
  }
}
