variable "group_ids" {
  description = "Map of NetBird group name -> group ID (from the groups unit's `group_ids` output). auto_groups below are group NAMES; this module resolves them to IDs."
  type        = map(string)
  default     = {}
}

variable "setup_keys" {
  description = "NetBird machine-enrollment setup keys, keyed by name. Machine enrollment bypasses user MFA by design (RFC §6a) — keep these ephemeral/usage-limited/group-scoped, never standing+unlimited."
  type = map(object({
    type           = optional(string, "reusable") # reusable|one-off
    expiry_seconds = optional(number, 604800)     # 7d default; not a standing credential
    usage_limit    = optional(number, 1)          # 0 = unlimited — avoid in practice
    ephemeral      = optional(bool, false)
    auto_groups    = optional(list(string), []) # group names
  }))
  default = {}
}
