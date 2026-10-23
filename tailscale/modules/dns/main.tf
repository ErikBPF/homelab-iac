resource "tailscale_dns_nameservers" "this" {
  nameservers = var.nameservers
}

resource "tailscale_dns_preferences" "this" {
  magic_dns = var.magic_dns
}

resource "tailscale_dns_search_paths" "this" {
  search_paths = var.search_paths
}

resource "tailscale_dns_split_nameservers" "this" {
  for_each = var.split_nameservers

  domain      = each.key
  nameservers = each.value
}

# Adopt the existing split rule without changing its resolver or other zones.
import {
  to = tailscale_dns_split_nameservers.this["homelab.pastelariadev.com"]
  id = "homelab.pastelariadev.com"
}
