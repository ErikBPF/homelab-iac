include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//tunnel"
}

# Tunnel ingress is account-scoped → override the provider token with the
# broader account token (Account -> Cloudflare Tunnel -> Edit).
inputs = {
  cf_api_token = get_env("CLOUDFLARE_TUNNEL_API_TOKEN")

  # TODO(import): filled once the token lands — fetch account_id + the live
  # ingress per tunnel, then import `<account_id>/<tunnel_id>` to zero-diff.
  account_id = "TODO_ACCOUNT_ID"
  tunnels    = {}
}
