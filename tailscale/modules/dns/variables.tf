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
