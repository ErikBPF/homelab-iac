variable "zone_id" {
  description = "Cloudflare zone the token is scoped to (DNS edit only)."
  type        = string
}

variable "token_name" {
  description = "Display name of the API token in the Cloudflare dashboard."
  type        = string
}

variable "zone_read" {
  description = "Also grant Zone:Read. cert-manager needs it to resolve the zone; certbot does not."
  type        = bool
  default     = false
}
