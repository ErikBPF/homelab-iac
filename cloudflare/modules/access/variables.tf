variable "account_id" {
  description = "Cloudflare account ID (Access apps are account-scoped)."
  type        = string
}

variable "applications" {
  description = <<-EOT
    Access applications keyed by their display name (the key IS the app name, so
    it must match an existing app's name when adopting one via import). Each
    protects `domain` and generates up to two policies:
      - an "allow" email policy for the emails in `allowed_emails`;
      - a "non_identity" service-token policy including a freshly-minted token
        (when `create_service_token`) and/or any `extra_service_token_ids`
        (existing tokens referenced by id).
    App-hardening attrs default to hardened values for new apps; override per app
    to reproduce an already-live app faithfully (set `same_site_cookie_attribute`
    to null to omit it).
  EOT
  type = map(object({
    domain                     = string
    session_duration           = optional(string, "24h")
    app_launcher_visible       = optional(bool, false)
    http_only_cookie_attribute = optional(bool, true)
    same_site_cookie_attribute = optional(string) # null = omit; set "strict" to harden
    enable_binding_cookie      = optional(bool, true)
    auto_redirect_to_identity  = optional(bool, false)
    skip_interstitial          = optional(bool, false)

    allowed_emails          = optional(list(string), [])
    email_policy_name       = optional(string, "allowed-emails")
    email_policy_precedence = optional(number, 2)

    create_service_token    = optional(bool, false)
    service_token_name      = optional(string, "")
    extra_service_token_ids = optional(list(string), [])
    token_policy_name       = optional(string, "device-service-token")
    token_policy_precedence = optional(number, 1)
  }))
}
