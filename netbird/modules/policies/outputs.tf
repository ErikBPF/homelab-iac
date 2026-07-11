output "policy_ids" {
  description = "Map of policy name -> NetBird policy ID."
  value       = { for k, v in netbird_policy.this : k => v.id }
}
