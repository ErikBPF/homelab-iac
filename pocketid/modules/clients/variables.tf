variable "clients" {
  description = <<-EOT
    PocketID OIDC clients, keyed by display name. The NetBird client is public +
    PKCE (no secret). `client_id` may be pinned so `terragrunt import` reconciles
    an EXISTING client cleanly (G2 = import, never re-issue a live client-id);
    omit it to let PocketID auto-generate. callback_urls / logout_callback_urls
    must MATCH the live client on import or the first plan shows a diff.
  EOT
  type = map(object({
    # Pin to import an existing client with ZERO change; omit (null) to auto-gen.
    client_id            = optional(string)
    is_public            = optional(bool, false)
    pkce_enabled         = optional(bool, true)
    callback_urls        = list(string)
    logout_callback_urls = optional(list(string), [])
    # PocketID group IDs allowed to use the client; empty = all users.
    allowed_user_groups = optional(list(string), [])
    launch_url          = optional(string)
  }))
  default = {}
}
