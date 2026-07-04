variable "zone_id" {
  description = "Cloudflare zone the rate-limit ruleset belongs to."
  type        = string
}

variable "rules" {
  description = <<-EOT
    Rate-limit rules keyed by a short name. All rules for the zone live in one
    http_ratelimit ruleset (Cloudflare allows one entrypoint ruleset per phase
    per zone). `period` must be one of 10/60/120/300/600/3600 seconds.
  EOT
  type = map(object({
    description         = string
    expression          = string
    period              = number
    requests_per_period = number
    mitigation_timeout  = optional(number, 600)
    action              = optional(string, "block")
  }))
  default = {}
}
