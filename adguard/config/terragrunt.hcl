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
    blocked_services = null
    blocked_services_pause_schedule = {
      time_zone = "UTC"
    }
    dns = {
      allowed_clients            = null
      blocked_hosts              = ["version.bind", "id.server", "hostname.bind"]
      blocked_response_ttl       = 10
      blocking_ipv4              = null
      blocking_ipv6              = null
      blocking_mode              = "default"
      bootstrap_dns              = ["9.9.9.10", "149.112.112.10", "2620:fe::10", "2620:fe::fe:10"]
      cache_enabled              = true
      cache_optimistic           = false
      cache_size                 = 4194304
      cache_ttl_max              = 0
      cache_ttl_min              = 0
      disable_ipv6               = false
      disallowed_clients         = null
      dnssec_enabled             = false
      edns_cs_custom_ip          = null
      edns_cs_enabled            = false
      edns_cs_use_custom         = false
      fallback_dns               = null
      local_ptr_upstreams        = null
      protection_enabled         = true
      rate_limit                 = 20
      rate_limit_subnet_len_ipv4 = 24
      rate_limit_subnet_len_ipv6 = 56
      rate_limit_whitelist       = null
      resolve_clients            = true
      upstream_dns               = ["https://dns10.quad9.net/dns-query"]
      upstream_mode              = "load_balance"
      upstream_timeout           = 10
      use_private_ptr_resolvers  = false
    }
    filtering = {
      enabled         = true
      update_interval = 24
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
      interval        = 24
    }
  }
}
