include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//dns"
}

# Cloudflare Tunnel CNAMEs (proxied) — the public edge for tunnel-exposed
# services. nanda/qualitransp removed 2026-06-29 with their tunnels (decommission).
inputs = {
  zone_id   = "2c4ac8f72b5661f3d360d4dececbd4ba"
  zone_name = "pastelariadev.com"

  records = {
    "ha.pastelariadev.com" = {
      type    = "CNAME"
      value   = "fe892a2a-213b-484c-948f-5b666be1fdd9.cfargotunnel.com"
      proxied = true
    }
  }
}
