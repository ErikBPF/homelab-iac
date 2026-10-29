include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//api-token"
}

# Least-scope Cloudflare API token for cert-manager's DNS-01 solver on the
# monitoring hostnames (grafana/prometheus.homelab.pastelariadev.com).
# cert-manager lists zones before it writes the challenge, so this token needs
# Zone:Read on top of DNS:Edit — unlike swag-dns01, which gets the zone by name.
#
# ── BRIDGE to the cluster (state → secret) ──────────────────────────────────
#   terragrunt output -raw token_value \
#     | homelab-gitops/scripts/bootstrap-monitoring-dns01-token.sh
# The script applies server-side and removes the last-applied annotation, so the
# value is not readable from the Secret's metadata afterwards.
inputs = {
  zone_id    = "2c4ac8f72b5661f3d360d4dececbd4ba"
  zone_read  = true
  token_name = "certmanager-dns01"
}
