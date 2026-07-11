variable "group_ids" {
  description = "Map of NetBird group name -> group ID (from the groups unit's `group_ids` output). Rule sources/destinations below are group NAMES; this module resolves them to IDs."
  type        = map(string)
  default     = {}
}

variable "posture_check_ids" {
  description = "Map of NetBird posture-check name -> ID (from the posture-checks unit's `posture_check_ids` output)."
  type        = map(string)
  default     = {}
}

variable "policies" {
  description = "NetBird policies, keyed by name. Default-deny baseline (RFC §6/§8): NetBird denies traffic between peers unless an explicit rule accepts it — every accept below is a deliberate exception, mirroring tailscale/acl's policy.hujson shape."
  type = map(object({
    description           = optional(string, "")
    enabled               = optional(bool, true)
    source_posture_checks = optional(list(string), [])
    rules = list(object({
      name          = string
      description   = optional(string, "")
      enabled       = optional(bool, true)
      action        = string                  # accept|drop
      protocol      = optional(string, "all") # tcp|udp|icmp|all|netbird-ssh
      bidirectional = optional(bool, true)
      sources       = optional(list(string), []) # group names
      destinations  = optional(list(string), []) # group names
      ports         = optional(list(string), [])
    }))
  }))
  default = {}
}
