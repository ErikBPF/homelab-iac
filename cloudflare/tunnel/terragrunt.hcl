include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//tunnel"
}

# Uses the shared CLOUDFLARE_API_TOKEN (dual-scope) from the root. This unit now
# owns the tunnel resource itself (cloudflare_zero_trust_tunnel_cloudflared), not
# just its ingress config — so the connector token (CLOUDFLARE_TUNNEL_TOKEN) is
# Terraform-managed (RFC 2026-06-28 cloudflare-token-terraform-migration, Ph3).
# Scope: homelab tunnels only. nandacsilveira / qualitransp (separate projects)
# and the empty-ingress "homelab" tunnel are intentionally not managed here.
# Public-service backends resolved from the vendored fleet SSOT (fleet.json,
# desktop-nixos `flake.fleet`; RFC 2026-06-29 P2). fqdn + backend host:port come
# from fleet.services.<svc> (scope=public); host→IP via fleet.hosts. This
# corrected rpg .112 (stale install IP) → kepler .230. Order is explicit because
# Cloudflare ingress is order-sensitive (catch-all must be last).
#
# ── ONE-TIME IMPORT (Ph3) ───────────────────────────────────────────────────
# The tunnel fe892a2a-… already exists (made in the dashboard). Bring it under
# state before the first apply (wired LAN host, bootstrap CLOUDFLARE_API_TOKEN +
# UNIFI_STATE_PASSPHRASE in env):
#   terragrunt import \
#     'cloudflare_zero_trust_tunnel_cloudflared.this["homeassistant-remote-access"]' \
#     '35fedd0568084dec44d573c5736c0132/fe892a2a-213b-484c-948f-5b666be1fdd9'
# `secret` is write-only — keep the placeholder; plan won't diff it. Then bridge:
#   terragrunt output -json tunnel_tokens | jq -r '."homeassistant-remote-access"'
#   → OpenBao secret/home/tunneling CLOUDFLARE_TUNNEL_TOKEN → kick-stack tunneling.
locals {
  fleet = jsondecode(file(find_in_parent_folders("fleet.json")))
  svc   = local.fleet.services
  url   = { for k, s in local.svc : k => "http://${local.fleet.hosts[s.backend.host].ip}:${s.backend.port}" }
}

inputs = {
  account_id = "35fedd0568084dec44d573c5736c0132"

  tunnels = {
    "homeassistant-remote-access" = {
      # Write-only placeholder; the existing tunnel's secret is unreadable on
      # import. Set a real `openssl rand -base64 32` value only to rotate.
      secret = get_env("CF_TUNNEL_SECRET_HOMEASSISTANT_REMOTE_ACCESS", "placeholder-set-to-rotate")
      ingress = [
        { hostname = local.svc.ha.fqdn, service = local.url.ha },
        { service = "http_status:404" }, # catch-all (required last)
      ]
    }
  }
}
