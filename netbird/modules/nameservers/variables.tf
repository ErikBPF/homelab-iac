variable "group_ids" {
  description = "Map of NetBird group name -> group ID (from the groups unit's `group_ids` output). `groups` below are group NAMES; this module resolves them to IDs."
  type        = map(string)
  default     = {}
}

variable "nameserver_groups" {
  description = <<-EOT
    NetBird nameserver groups, keyed by name. Split-DNS (RFC §3/§8.4): set
    `primary = false` + `domains = [zone]` so peers resolve only that zone via
    these nameservers and everything else via their default resolver — mirrors
    the Tailscale MagicDNS split-DNS. `groups` are the distribution groups
    (which peers get the DNS), by NAME, resolved to IDs here.
  EOT
  type = map(object({
    description            = optional(string, "")
    enabled                = optional(bool, true)
    primary                = optional(bool, false)
    domains                = optional(list(string), [])
    search_domains_enabled = optional(bool, false)
    groups                 = optional(list(string), []) # group names
    nameservers = list(object({
      ip      = string
      ns_type = optional(string, "udp") # udp only, per the provider
      port    = optional(number, 53)
    }))
  }))
  default = {}
}
