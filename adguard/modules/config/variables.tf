variable "config" {
  description = "Provider-supported, non-secret AdGuard Home configuration."
  type = object({
    blocked_services                = set(string)
    blocked_services_pause_schedule = object({ time_zone = string })
    dns = object({
      allowed_clients            = set(string)
      blocked_hosts              = set(string)
      blocked_response_ttl       = number
      blocking_ipv4              = string
      blocking_ipv6              = string
      blocking_mode              = string
      bootstrap_dns              = list(string)
      cache_enabled              = bool
      cache_optimistic           = bool
      cache_size                 = number
      cache_ttl_max              = number
      cache_ttl_min              = number
      disable_ipv6               = bool
      disallowed_clients         = set(string)
      dnssec_enabled             = bool
      edns_cs_custom_ip          = string
      edns_cs_enabled            = bool
      edns_cs_use_custom         = bool
      fallback_dns               = list(string)
      local_ptr_upstreams        = set(string)
      protection_enabled         = bool
      rate_limit                 = number
      rate_limit_subnet_len_ipv4 = number
      rate_limit_subnet_len_ipv6 = number
      rate_limit_whitelist       = list(string)
      resolve_clients            = bool
      upstream_dns               = list(string)
      upstream_mode              = string
      upstream_timeout           = number
      use_private_ptr_resolvers  = bool
    })
    filtering = object({
      enabled         = bool
      update_interval = number
    })
    parental_control = bool
    querylog = object({
      anonymize_client_ip = bool
      enabled             = bool
      ignored             = set(string)
      ignored_enabled     = bool
      interval            = number
    })
    rewrites     = bool
    safebrowsing = bool
    safesearch = object({
      enabled  = bool
      services = set(string)
    })
    stats = object({
      enabled         = bool
      ignored         = set(string)
      ignored_enabled = bool
      interval        = number
    })
  })
}
