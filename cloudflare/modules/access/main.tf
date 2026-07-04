# Cloudflare Access edge for a tunnel-exposed service. Two ways in:
#   - a service token (non-interactive) for the ESP32 device — it sends
#     CF-Access-Client-Id / CF-Access-Client-Secret headers; Access validates
#     them at the edge BEFORE the request reaches the tunnel/origin.
#   - optional email identity policy for a human browser (the "email auth" path).
# Access is evaluated in front of the tunnel for `domain`, so unauthenticated
# internet traffic is rejected at Cloudflare, never reaching LiteLLM.
#
# NOTE: creating these needs an API token with Account > Access: Apps & Policies
# (+ Service Tokens) Edit — the shared dual-scope CLOUDFLARE_API_TOKEN cannot.
# See the bootstrap note in cloudflare/access/terragrunt.hcl.

resource "cloudflare_zero_trust_access_application" "this" {
  account_id           = var.account_id
  name                 = var.app_name
  domain               = var.domain
  type                 = "self_hosted"
  session_duration     = var.session_duration
  app_launcher_visible = false
}

resource "cloudflare_zero_trust_access_service_token" "device" {
  account_id = var.account_id
  name       = var.service_token_name
}

# Non-interactive: the device's service token. `non_identity` means no login
# prompt — the CF-Access-Client-Id/Secret header pair is sufficient.
resource "cloudflare_zero_trust_access_policy" "service_token" {
  account_id     = var.account_id
  application_id = cloudflare_zero_trust_access_application.this.id
  name           = "device-service-token"
  precedence     = 1
  decision       = "non_identity"

  include {
    service_token = [cloudflare_zero_trust_access_service_token.device.id]
  }
}

# Interactive: allow-listed emails for a human browser (optional).
resource "cloudflare_zero_trust_access_policy" "emails" {
  count = length(var.allowed_emails) > 0 ? 1 : 0

  account_id     = var.account_id
  application_id = cloudflare_zero_trust_access_application.this.id
  name           = "allowed-emails"
  precedence     = 2
  decision       = "allow"

  include {
    email = var.allowed_emails
  }
}
