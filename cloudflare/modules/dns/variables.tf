variable "zone_id" {
  description = "Cloudflare zone ID."
  type        = string
}

variable "zone_name" {
  description = "Zone apex domain, used to derive short record names from FQDN keys."
  type        = string
}

variable "records" {
  description = "DNS records keyed by FQDN."
  type = map(object({
    type    = string
    value   = string
    proxied = optional(bool, false)
    ttl     = optional(number, 1) # 1 = automatic (required when proxied)
  }))
  default = {}
}
