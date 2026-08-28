# Monthly spend visibility for the Oracle compartment. OCI budgets notify but
# do not stop usage. Not gated by create_instance so alerts remain active while
# a VM is deferred.

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
  display_name   = "${var.name}-monthly-spend"
  description    = "Monthly spend target for the offsite Oracle resources."
}

resource "oci_budget_alert_rule" "voyager_any_spend" {
  count          = var.create_budget ? 1 : 0
  budget_id      = oci_budget_budget.voyager[0].id
  display_name   = "actual-usage-warning"
  type           = "ACTUAL"
  threshold      = var.budget_alert_threshold
  threshold_type = "ABSOLUTE"
  recipients     = var.budget_alert_email
  message        = "OCI actual usage crossed USD ${var.budget_alert_threshold}. Review current spend."
}

resource "oci_budget_alert_rule" "voyager_forecast" {
  count          = var.create_budget ? 1 : 0
  budget_id      = oci_budget_budget.voyager[0].id
  display_name   = "monthly-spend-forecast"
  type           = "FORECAST"
  threshold      = var.budget_amount
  threshold_type = "ABSOLUTE"
  recipients     = var.budget_alert_email
  message        = "OCI forecast spend reached the USD ${var.budget_amount} monthly budget."
}
