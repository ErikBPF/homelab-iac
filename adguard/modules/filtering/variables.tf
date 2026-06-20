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
