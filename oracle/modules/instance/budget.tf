# Free-tier safety net. Everything here is meant to stay Always-Free ($0); this
# budget + alert make sure a PAYG upgrade (or any accidental paid resource)
# can't bill silently. Budgets live in the root/tenancy compartment and target
# the compartment we deploy into. Not gated by create_instance — the guard
# should exist even while the VM is deferred.

# A COMPARTMENT-target budget is unique per compartment, so only ONE host's
# unit should create it; the others target the same compartment and would
# collide. create_budget defaults true (voyager owns the guard); secondary
# units (telstar, …) set it false and rely on the shared guard.
resource "oci_budget_budget" "voyager" {
  count          = var.create_budget ? 1 : 0
  compartment_id = var.oci_tenancy_ocid
  amount         = var.budget_amount
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.compartment_ocid]
  display_name   = "${var.name}-freetier-guard"
  description    = "Free-tier guard for the offsite Oracle resources -- expected spend is $0."
}

resource "oci_budget_alert_rule" "voyager_any_spend" {
  count          = var.create_budget ? 1 : 0
  budget_id      = oci_budget_budget.voyager[0].id
  display_name   = "any-actual-spend"
  type           = "ACTUAL"
  threshold      = var.budget_alert_threshold
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  message        = "OCI actual spend crossed the free-tier guard (expected $0). Investigate immediately."
}
