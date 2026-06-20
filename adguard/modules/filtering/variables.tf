variable "rewrites" {
  description = "DNS rewrites: domain => answer."
  type        = map(string)
  default     = {}
}

variable "user_rules" {
  description = "AdGuard user rules (allow/block), in order. Singleton."
  type        = list(string)
  default     = []
}

variable "list_filters" {
  description = "Blocklist/allowlist subscriptions, keyed by name."
  type = map(object({
    url       = string
    enabled   = optional(bool, true)
    whitelist = optional(bool, false)
  }))
  default = {}
}
