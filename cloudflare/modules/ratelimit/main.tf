# Zone-level rate limiting (WAF http_ratelimit phase). One ruleset holds every
# rate-limit rule for the zone — add rules via var.rules. Per-IP counting bounds
# abuse of a public endpoint if a device credential leaks; the CF Access edge
# still fronts it, this is depth behind that.
#
# NOTE: one entrypoint ruleset per phase per zone. If the zone already has an
# http_ratelimit ruleset (made in the dashboard), import it before apply.

resource "cloudflare_ruleset" "ratelimit" {
  count = length(var.rules) > 0 ? 1 : 0

  zone_id = var.zone_id
  name    = "homelab rate limits"
  kind    = "zone"
  phase   = "http_ratelimit"

  dynamic "rules" {
    for_each = var.rules
    content {
      action      = rules.value.action
      description = rules.value.description
      expression  = rules.value.expression
      enabled     = true

      ratelimit {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = rules.value.period
        requests_per_period = rules.value.requests_per_period
        mitigation_timeout  = rules.value.mitigation_timeout
      }
    }
  }
}
