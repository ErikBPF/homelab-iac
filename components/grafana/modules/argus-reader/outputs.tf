output "service_account_state_id" {
  description = "Composite Terraform identity (org:account), not a numeric Grafana API account ID."
  value       = grafana_service_account.argus.id
}
