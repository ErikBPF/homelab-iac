#!/usr/bin/env bats

@test "Oracle budget permits small paid usage and alerts before overspend" {
  variables=oracle/modules/instance/variables.tf
  budget=oracle/modules/instance/budget.tf

  grep -A3 'variable "budget_amount"' "$variables" | grep -Eq 'default[[:space:]]*=[[:space:]]*1$'
  grep -A3 'variable "budget_alert_threshold"' "$variables" | grep -Eq 'default[[:space:]]*=[[:space:]]*0\.1$'
  grep -Fq 'threshold_type = "ABSOLUTE"' "$budget"
  grep -Fq 'type           = "ACTUAL"' "$budget"
  grep -Fq 'type           = "FORECAST"' "$budget"
  grep -Fq 'message        = "OCI actual usage crossed USD ${var.budget_alert_threshold}. Review current spend."' "$budget"
  grep -Fq 'message        = "OCI forecast spend reached the USD ${var.budget_amount} monthly budget."' "$budget"
}
