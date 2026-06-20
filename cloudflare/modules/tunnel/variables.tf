variable "account_id" {
  description = "Cloudflare account ID (tunnels are account-scoped)."
  type        = string
}

variable "tunnels" {
  description = <<-EOT
    Tunnel ingress configs, keyed by a friendly name. Each `ingress` list must
    end with a catch-all rule (no hostname, e.g. service = "http_status:404").
  EOT
  type = map(object({
    tunnel_id = string
    ingress = list(object({
      hostname = optional(string)
      path     = optional(string)
      service  = string
    }))
  }))
  default = {}
}
