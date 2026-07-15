# Root Terragrunt config for the AdGuard Home component. Units under
# adguard/<stack>/ include this. Generates the adguard provider + local
# encrypted state.
#
# Auth: host/username/scheme are non-secret (below); the password comes from
# ADGUARD_PASSWORD in the shell (.env via dotenv) — never on disk or in state.
#
# OWNERSHIP (split): Terraform owns rewrites + user_rules + list_filters via the
# AdGuard API. The base config (DNS upstreams, dhcp, tls, querylog/stats) stays
# in servarr's AdGuardHome.yaml — the provider's adguard_config can't manage it
# cleanly (its update rejects the disabled-DHCP block). `just sync-servarr`
# excludes config/adguard/AdGuardHome.yaml so a sync can't clobber TF's changes.

generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    provider "adguard" {
      host     = "adguard.homelab.pastelariadev.com"
      username = "erik"
      scheme   = "https"
      # password from ADGUARD_PASSWORD env
    }
  EOT
}
