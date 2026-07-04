include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//access"
}

# Cloudflare Access edge for the public whisper route (whisper.pastelariadev.com,
# tunnel ingress → http://litellm:4000). The ESP32 (cosmo-notes) authenticates
# with the minted service token (CF-Access-Client-Id/Secret headers); a human
# browser can use the email policy. fqdn comes from the vendored fleet SSOT
# (fleet.services.whisper, scope=public).
#
# ── BOOTSTRAP (one-time, same shape as swag-token) ──────────────────────────
# Creating Access apps/policies/service-tokens needs an API token holding
# Account > Access: Apps and Policies: Edit  +  Access: Service Tokens: Edit.
# The shared dual-scope CLOUDFLARE_API_TOKEN (Zone:DNS + Tunnel) CANNOT create
# them. For THIS unit's apply, point CLOUDFLARE_API_TOKEN at a bootstrap token
# with those Access scopes (or the Global API Key), apply, then revert
# CLOUDFLARE_API_TOKEN to the limited token for every other unit.
# Apply only from a wired LAN host (repo convention; state is local+encrypted).
#
# ── BRIDGE to the device (state → secrets.h) ────────────────────────────────
#   terragrunt output -json service_token_client_ids     | jq -r '."cosmo-whisper"' → CF_ACCESS_CLIENT_ID
#   terragrunt output -json service_token_client_secrets  | jq -r '."cosmo-whisper"' → CF_ACCESS_CLIENT_SECRET
# Paste both into cosmo-notes firmware/src/secrets.h (gitignored), point
# LITELLM_HOST at whisper.pastelariadev.com, rebuild + flash (or OTA).
#
# The module is a map — add more Access-protected public services (e.g. the OTA
# firmware host, or Home Assistant) as extra `applications` entries; each mints
# its own service token.

locals {
  fleet = jsondecode(file(find_in_parent_folders("fleet.json")))
}

inputs = {
  account_id = "35fedd0568084dec44d573c5736c0132"

  applications = {
    # NEW app — hardened defaults, mints its own service token for the device.
    "cosmo-whisper" = {
      domain                     = local.fleet.services.whisper.fqdn
      same_site_cookie_attribute = "strict" # hardened (new app)
      create_service_token       = true
      service_token_name         = "cosmo-notes"
      # Interactive (browser) access for the admin, alongside the device token.
      allowed_emails = ["erik.bogado@nstech.com.br"]
    }

    # EXISTING app (id 5f2a19bc…) — reproduced from the live config so `import`
    # adopts it as a no-op (do NOT change live HA / break the Alexa path). Email
    # + two existing service tokens (homeassistant-remote-access, test). Attrs
    # mirror live (launcher visible, no SameSite, binding off, skip interstitial).
    "Home-assistant" = {
      domain                     = "ha.pastelariadev.com"
      app_launcher_visible       = true
      same_site_cookie_attribute = null
      enable_binding_cookie      = false
      skip_interstitial          = true

      allowed_emails          = ["erikbogado@gmail.com"]
      email_policy_name       = "allow"
      email_policy_precedence = 1

      create_service_token = false
      extra_service_token_ids = [
        "63f9126b-6601-42b2-9288-3844df0f9a87", # homeassistant-remote-access
        "4480cb30-1a1f-4fe7-946d-881214ee3aa8", # test
      ]
      token_policy_name       = "homeassistant-alexa-auth"
      token_policy_precedence = 2
    }
  }
}
