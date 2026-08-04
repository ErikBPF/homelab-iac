variable "nameservers" {
  description = "Global DNS nameservers for the tailnet."
  type        = list(string)
  default     = []
}

variable "magic_dns" {
  description = "Enable MagicDNS."
  type        = bool
  default     = true
}

variable "search_paths" {
  description = "DNS search domains."
  type        = list(string)
  default     = []
}

variable "split_nameservers" {
  description = "Domain-specific DNS nameservers for the tailnet."
  type        = map(set(string))
  default     = {}
}
