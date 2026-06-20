include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//tunnel"
}

# Uses the shared CLOUDFLARE_API_TOKEN (dual-scope) from the root.
# Scope: homelab tunnels only. nandacsilveira / qualitransp (separate projects)
# and the empty-ingress "homelab" tunnel are intentionally not managed here.
inputs = {
  account_id = "35fedd0568084dec44d573c5736c0132"

  tunnels = {
    "homeassistant-remote-access" = {
      tunnel_id = "fe892a2a-213b-484c-948f-5b666be1fdd9"
      ingress = [
        { hostname = "ha.pastelariadev.com", service = "http://192.168.10.115:8123" },
        { hostname = "rpg.pastelariadev.com", service = "http://192.168.10.112:7860" },
        { service = "http_status:404" }, # catch-all (required last)
      ]
    }
  }
}
