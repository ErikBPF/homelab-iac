variable "records" {
  description = "Static DNS records, keyed by record name."
  type = map(object({
    type    = string # A | AAAA | CNAME | MX | NS | PTR | SOA | SRV | TXT
    record  = string # record content (IP for A/AAAA, host for CNAME, ...)
    enabled = optional(bool, true)
    ttl     = optional(number)
  }))
  default = {}
}
