variable "account_id" {
  description = "Cloudflare account ID (Access apps are account-scoped)."
  type        = string
}

variable "app_name" {
  description = "Display name of the Access application."
  type        = string
}

variable "domain" {
  description = "FQDN the Access application protects (must match a tunnel ingress hostname / DNS record)."
  type        = string
}

variable "service_token_name" {
  description = "Name of the service token minted for non-interactive (device) access."
  type        = string
}

variable "allowed_emails" {
  description = "Emails allowed via interactive (identity) login, in addition to the device service token. Empty = service-token only."
  type        = list(string)
  default     = []
}

variable "session_duration" {
  description = "Interactive session lifetime."
  type        = string
  default     = "24h"
}
