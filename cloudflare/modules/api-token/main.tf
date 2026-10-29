# A least-scope Cloudflare API token: Zone:DNS:Edit on a single zone. Built for
# SWAG's DNS-01 wildcard-cert renewal (certbot dns-cloudflare) so the host no
# longer shares the broad dual-scope CLOUDFLARE_API_TOKEN. cert-manager also
# needs Zone:Read to look the zone up, so that group is opt-in per consumer.
# The token VALUE is only returned at create time (sensitive) — see outputs.tf.

data "cloudflare_api_token_permission_groups" "all" {}

resource "cloudflare_api_token" "this" {
  name = var.token_name

  policy {
    # "DNS Write" is the Zone-level Edit permission group DNS-01 needs.
    # "Zone Read" is added only when the consumer resolves the zone itself.
    # Nothing else — no account, no tunnel, no other zones.
    permission_groups = concat(
      [data.cloudflare_api_token_permission_groups.all.zone["DNS Write"]],
      var.zone_read ? [data.cloudflare_api_token_permission_groups.all.zone["Zone Read"]] : [],
    )
    resources = {
      "com.cloudflare.api.account.zone.${var.zone_id}" = "*"
    }
  }

  # Replacement must mint the successor before the old token dies: a botched
  # rotation would otherwise leave the consumer with a dead credential.
  lifecycle {
    create_before_destroy = true
  }
}
