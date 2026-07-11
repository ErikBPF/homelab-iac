output "group_ids" {
  description = "Map of group name -> NetBird group ID. Paste into the policies/setup-keys units' group_ids input after this unit is applied (this repo doesn't use cross-stack `dependency` blocks — see unifi/environments/home/wlan for the same hardcoded-ID-after-first-apply pattern)."
  value       = { for k, v in netbird_group.this : k => v.id }
}
