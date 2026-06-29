# A least-scope Cloudflare API token: Zone:DNS:Edit on a single zone. Built for
# SWAG's DNS-01 wildcard-cert renewal (certbot dns-cloudflare) so the host no
# longer shares the broad dual-scope CLOUDFLARE_API_TOKEN. The token VALUE is
# only returned at create time (sensitive) — see outputs.tf for the bridge.

data "cloudflare_api_token_permission_groups" "all" {}

resource "cloudflare_api_token" "this" {
  name = var.token_name

  policy {
    # "DNS Write" is the Zone-level Edit permission group certbot needs for
    # DNS-01. Nothing else — no account, no tunnel, no other zones.
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.${var.zone_id}" = "*"
    }
  }
}
