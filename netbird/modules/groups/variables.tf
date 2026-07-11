variable "groups" {
  description = "NetBird groups, keyed by name. peers/resources are IDs (not names) — leave empty at scaffold time and fill in once real peers/resources exist (netbird_peer/netbird_network_resource are out of WP4 scope)."
  type = map(object({
    peers     = optional(list(string), [])
    resources = optional(list(string), [])
  }))
  default = {}
}
