variable "group_ids" {
  description = "Map of NetBird group name -> group ID (from the groups unit's `group_ids` output). `groups`, `peer_groups`, and `access_control_groups` below are group NAMES; this module resolves them to IDs. A single routing `peer` is a literal peer ID (not a name)."
  type        = map(string)
  default     = {}
}

variable "routes" {
  description = <<-EOT
    NetBird routes, keyed by name (RFC §3 — "routes if any"). Expose a subnet or
    domains to overlay peers through a routing peer. Set EITHER `peer` (one
    routing peer ID) OR `peer_groups` (group names), never both. `groups` are the
    distribution groups (NAMES) that receive the route. Empty by default — this
    is a scaffold; see the routes unit's terragrunt.hcl for the prerequisites.
  EOT
  type = map(object({
    network_id            = string # groups HA routes to the same destination
    description           = optional(string, "")
    enabled               = optional(bool, true)
    network               = optional(string)           # CIDR, e.g. "192.168.10.0/24" (conflicts with domains)
    domains               = optional(list(string), []) # conflicts with network
    metric                = optional(number, 9999)     # lower = higher priority
    masquerade            = optional(bool, true)
    peer                  = optional(string)           # single routing peer ID (mutually exclusive with peer_groups)
    peer_groups           = optional(list(string), []) # routing-peer group names (mutually exclusive with peer)
    groups                = list(string)               # distribution group names
    access_control_groups = optional(list(string), [])
  }))
  default = {}
}
