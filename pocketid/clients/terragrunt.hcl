include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//clients"
}

# The NetBird OIDC client (RFC 2026-07-11-netbird-terraform-declarative-admin.md
# §3). public + PKCE, no secret. `client_id` is pinned to the value ALREADY live
# in PocketID and baked into the netbird control plane (desktop-nixos
# modules/hosts/discovery/netbird-server.nix: management.json PKCE ClientID +
# dashboard AUTH_CLIENT_ID), so `terragrunt import` reconciles the existing
# client with ZERO change (G2 = import — never re-issue a client-id, that would
# break the whole mesh's OIDC).
#
# callback_urls MUST match the live client exactly or the first plan shows a
# diff:
#   - https://nb.<zone>/       dashboard redirect (netbird-server.nix
#                              AUTH_REDIRECT_URI = "/"; dashboard SSO deferred
#                              but the URL is still the registered redirect)
#   - http://localhost:53000   netbird CLI loopback PKCE flow (`netbird up`,
#                              management.json PKCEAuthorizationFlow RedirectURLs)
#
# TODO(Phase S, human op): import BEFORE the first apply, then confirm no-op:
#   cd pocketid/clients
#   terragrunt import 'pocketid_client.this["netbird"]' 579d2f64-2bd0-4c5d-9796-f5a4ba2268d0
#   terragrunt plan   # MUST be "No changes"
# If plan shows a diff, the live client is the source of truth — reconcile this
# map to it (do not apply over it blindly). See IMPORT.md alongside this file.
inputs = {
  clients = {
    "netbird" = {
      client_id    = "579d2f64-2bd0-4c5d-9796-f5a4ba2268d0"
      is_public    = true
      pkce_enabled = true
      callback_urls = [
        "https://nb.homelab.pastelariadev.com/",
        "http://localhost:53000",
      ]
    }
  }
}
