include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//config"
}

inputs = {
  config = {
    blocked_services                = null
    blocked_services_pause_schedule = null
    dns = {
      allowed_clients            = null
      blocked_hosts              = ["version.bind", "id.server", "hostname.bind"]
      blocked_response_ttl       = 10
      blocking_ipv4              = null
      blocking_ipv6              = null
      blocking_mode              = "default"
      bootstrap_dns              = ["9.9.9.9", "149.112.112.112", "2620:fe::9", "2620:fe::fe:9"]
      cache_enabled              = true
      cache_optimistic           = true
      cache_size                 = 16777216
      cache_ttl_max              = 86400
      cache_ttl_min              = 300
      disable_ipv6               = false
      disallowed_clients         = null
      dnssec_enabled             = true
      edns_cs_custom_ip          = null
      edns_cs_enabled            = false
      edns_cs_use_custom         = false
      fallback_dns               = null
      local_ptr_upstreams        = null
      protection_enabled         = true
      rate_limit                 = 0
      rate_limit_subnet_len_ipv4 = 24
      rate_limit_subnet_len_ipv6 = 56
      rate_limit_whitelist       = null
      resolve_clients            = true
      upstream_dns               = ["tls://dns.quad9.net", "tls://1dot1dot1dot1.cloudflare-dns.com", "tls://dns.google"]
      upstream_mode              = "parallel"
      upstream_timeout           = 10
      use_private_ptr_resolvers  = false
    }
    filtering = {
      enabled         = true
      update_interval = 12
    }
    parental_control = false
    querylog = {
      anonymize_client_ip = false
      enabled             = true
      ignored             = null
      ignored_enabled     = false
      interval            = 2160
    }
    rewrites     = true
    safebrowsing = false
    safesearch = {
      enabled  = false
      services = ["bing", "duckduckgo", "ecosia", "google", "pixabay", "yandex", "youtube"]
    }
    stats = {
      enabled         = true
      ignored         = null
      ignored_enabled = false
      interval        = 2160
    }
  }
}
