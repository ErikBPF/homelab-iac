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
      # Optional per-rule origin settings — needed when the origin is behind a
      # reverse proxy reached by IP (set Host + TLS SNI/verify name), e.g. routing
      # a container-only service through SWAG at the host LAN IP.
      origin_request = optional(object({
        http_host_header   = optional(string)
        origin_server_name = optional(string)
        no_tls_verify      = optional(bool)
      }))
    }))
  }))
  default = {}
}
