include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//dns"
}

# Imported from the live pastelariadev.com zone. All three are Cloudflare Tunnel
# CNAMEs (proxied) — the public edge for tunnel-exposed services.
inputs = {
  zone_id   = "2c4ac8f72b5661f3d360d4dececbd4ba"
  zone_name = "pastelariadev.com"

  records = {
    "ha.pastelariadev.com" = {
      type    = "CNAME"
      value   = "fe892a2a-213b-484c-948f-5b666be1fdd9.cfargotunnel.com"
      proxied = true
    }
    "nanda.pastelariadev.com" = {
      type    = "CNAME"
      value   = "811b7064-c4d4-466e-9986-94b57fc55c70.cfargotunnel.com"
      proxied = true
    }
    "qualitransp.pastelariadev.com" = {
      type    = "CNAME"
      value   = "9b38f7d8-1069-4333-a324-52e682c1260d.cfargotunnel.com"
      proxied = true
    }
  }
}
