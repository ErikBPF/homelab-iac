# Root Terragrunt config for the AdGuard Home component. Units under
# adguard/<stack>/ include this. Generates the adguard provider + local
# encrypted state.
#
# Auth: host/username/scheme are non-secret (below); the password comes from
# ADGUARD_PASSWORD in the shell (.env via dotenv) — never on disk or in state.
#
# OWNERSHIP (transition): Terraform owns rewrites, user rules, list filters, and
# provider-supported singleton settings. Bootstrap/unsupported/secret settings
# remain in servarr's AdGuardHome.yaml until the post-apply no-op gate passes.

generate "provider" {
  path      = "provider_gen.tf"
  if_exists = "overwrite"
  contents  = <<-EOT
    provider "adguardhome" {
      host     = "adguard.homelab.pastelariadev.com"
      username = "erik"
      scheme   = "https"
      # password from ADGUARD_PASSWORD env
    }
  EOT
}
