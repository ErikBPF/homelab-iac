resource "tailscale_dns_nameservers" "this" {
  nameservers = var.nameservers
}

resource "tailscale_dns_preferences" "this" {
  magic_dns = var.magic_dns
}

resource "tailscale_dns_search_paths" "this" {
  search_paths = var.search_paths
}
