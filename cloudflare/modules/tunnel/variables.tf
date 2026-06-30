variable "account_id" {
  description = "Cloudflare account ID (tunnels are account-scoped)."
  type        = string
}

variable "tunnels" {
  description = <<-EOT
    Tunnels keyed by a friendly name (the key is the tunnel's display name).
    `secret` is the 32-byte base64 tunnel secret — write-only, so a placeholder
    is fine when importing an existing tunnel; rotate by setting a real value
    (openssl rand -base64 32) and re-applying. Each `ingress` list must end with
    a catch-all rule (no hostname, e.g. service = "http_status:404").
  EOT
  type = map(object({
    secret = string
    ingress = list(object({
      hostname = optional(string)
      path     = optional(string)
      service  = string
    }))
  }))
  default = {}
}
