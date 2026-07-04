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
#   terragrunt output -raw service_token_client_id       → CF_ACCESS_CLIENT_ID
#   terragrunt output -raw service_token_client_secret    → CF_ACCESS_CLIENT_SECRET
# Paste both into cosmo-notes firmware/src/secrets.h (gitignored), point
# LITELLM_HOST at whisper.pastelariadev.com, rebuild + flash (or OTA).

locals {
  fleet = jsondecode(file(find_in_parent_folders("fleet.json")))
}

inputs = {
  account_id         = "35fedd0568084dec44d573c5736c0132"
  app_name           = "cosmo whisper"
  domain             = local.fleet.services.whisper.fqdn
  service_token_name = "cosmo-notes"
  # Interactive (browser) access for the admin, alongside the device token.
  # Trim to [] for service-token-only.
  allowed_emails = ["erik.bogado@nstech.com.br"]
}
