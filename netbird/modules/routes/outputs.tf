output "route_ids" {
  description = "Map of route name -> NetBird route ID."
  value       = { for k, r in netbird_route.this : k => r.id }
}
