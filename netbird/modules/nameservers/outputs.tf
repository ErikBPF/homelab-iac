output "nameserver_group_ids" {
  description = "Map of nameserver-group name -> NetBird nameserver-group ID."
  value       = { for k, ns in netbird_nameserver_group.this : k => ns.id }
}
