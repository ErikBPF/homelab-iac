output "posture_check_ids" {
  description = "Map of posture-check name -> NetBird posture-check ID."
  value       = { for k, v in netbird_posture_check.this : k => v.id }
}
