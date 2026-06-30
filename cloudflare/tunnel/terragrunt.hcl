include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//tunnel"
}

# Uses the shared CLOUDFLARE_API_TOKEN (dual-scope) from the root.
# Scope: homelab tunnels only. nandacsilveira / qualitransp (separate projects)
# and the empty-ingress "homelab" tunnel are intentionally not managed here.
# Public-service backends resolved from the vendored fleet SSOT (fleet.json,
# desktop-nixos `flake.fleet`; RFC 2026-06-29 P2). fqdn + backend host:port come
# from fleet.services.<svc> (scope=public); host→IP via fleet.hosts. This
# corrected rpg .112 (stale install IP) → kepler .230. Order is explicit because
# Cloudflare ingress is order-sensitive (catch-all must be last).
locals {
  fleet = jsondecode(file(find_in_parent_folders("fleet.json")))
  svc   = local.fleet.services
  url   = { for k, s in local.svc : k => "http://${local.fleet.hosts[s.backend.host].ip}:${s.backend.port}" }
}

inputs = {
  account_id = "35fedd0568084dec44d573c5736c0132"

  tunnels = {
    "homeassistant-remote-access" = {
      tunnel_id = "fe892a2a-213b-484c-948f-5b666be1fdd9"
      ingress = [
        { hostname = local.svc.ha.fqdn, service = local.url.ha },
        { service = "http_status:404" }, # catch-all (required last)
      ]
    }
  }
}
