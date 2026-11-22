variable "org_id" {
  type        = number
  description = "Verified Grafana organization ID; never inferred from an account name."

  validation {
    condition     = var.org_id > 0 && floor(var.org_id) == var.org_id
    error_message = "org_id must be a verified positive integer."
  }
}

# OSS Viewer also reads dashboards/data sources; it is not an alerts-only role.
resource "grafana_service_account" "argus" {
  name        = "svc-argus-grafana-alert-reader"
  role        = "Viewer"
  org_id      = tostring(var.org_id)
  is_disabled = false

  lifecycle {
    prevent_destroy = true
  }
}
