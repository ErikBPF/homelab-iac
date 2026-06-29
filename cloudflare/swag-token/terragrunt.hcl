include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//api-token"
}

# Least-scope Cloudflare API token for SWAG's DNS-01 wildcard cert on discovery
# (*.homelab.pastelariadev.com). Replaces sharing the broad dual-scope
# CLOUDFLARE_API_TOKEN with the host. Zone:DNS:Edit on pastelariadev.com only.
#
# ── BOOTSTRAP (one-time) ────────────────────────────────────────────────────
# Creating an API token requires the provider credential to hold
# "User → API Tokens → Edit". The shared CLOUDFLARE_API_TOKEN is Zone:DNS +
# Tunnel only and CANNOT create tokens. So for THIS unit's apply, point
# CLOUDFLARE_API_TOKEN at a credential that can mint tokens (a bootstrap token
# with API-Tokens:Edit, or the account Global API Key), run the apply, then
# revert CLOUDFLARE_API_TOKEN to the limited token for every other unit.
#
# ── BRIDGE to SWAG (state → host) ───────────────────────────────────────────
# The minted value lives in this repo's encrypted state, not on the host:
#   terragrunt output -raw token_value
#   → servarr .env.sops: the SWAG cloudflare token var (the one swag-init writes
#     into /config/dns-conf/cloudflare.ini as dns_cloudflare_api_token)
#   → just push-env discovery
#   → recreate swag letting swag-init run (RUNBOOK; never --no-deps)
inputs = {
  zone_id    = "2c4ac8f72b5661f3d360d4dececbd4ba"
  token_name = "swag-dns01"
}
