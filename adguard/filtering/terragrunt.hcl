include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//filtering"
}

# Migrated from servarr's AdGuardHome.yaml (the homelab DNS rewrites + curated
# allow/block list). Filters (blocklist subscriptions) and the base DNS config
# follow before the YAML is retired.
inputs = {
  rewrites = {
    "*.k8s.pastelariadev.com"     = "192.168.10.210"
    "k8s.pastelariadev.com"       = "192.168.10.210"
    "*.homelab.pastelariadev.com" = "192.168.10.210"
    "homelab.pastelariadev.com"   = "192.168.10.210"
    "ha.pastelariadev.com"        = "192.168.10.210"
  }

  user_rules = [
    "# Allow own infra",
    "@@||pastelariadev.com^",
    "@@||tailscale.com^",
    "@@||login.tailscale.com^",
    "@@||controlplane.tailscale.com^",
    "",
    "# Block telemetry",
    "||telemetry.mozilla.org^",
    "||data.microsoft.com^",
    "||vortex.data.microsoft.com^",
    "||settings-win.data.microsoft.com^",
    "||watson.telemetry.microsoft.com^",
    "||activity.windows.com^",
    "||samsungads.com^",
    "||ads.samsung.com^",
  ]
}
