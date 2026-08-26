include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//filtering"
}

# Provider-supported live rewrites, user rules, and blocklist subscriptions.
# Servarr retains only runtime persistence and unsupported settings.
inputs = {
  rewrites = {
    "*.k8s.pastelariadev.com"              = "192.168.10.210"
    "k8s.pastelariadev.com"                = "192.168.10.210"
    "*.homelab.pastelariadev.com"          = "192.168.10.210"
    "homelab.pastelariadev.com"            = "192.168.10.210"
    "grafana.homelab.pastelariadev.com"    = "192.168.10.250"
    "prometheus.homelab.pastelariadev.com" = "192.168.10.250"
    "ha.pastelariadev.com"                 = "192.168.10.210"
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

  list_filters = {
    "AdGuard DNS filter" = {
      url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
      enabled = true
    }
    "AdAway Default Blocklist" = {
      url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"
      enabled = false
    }
    "HaGeZi Multi Pro++" = {
      url     = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt"
      enabled = true
    }
    "OISD Big" = {
      url     = "https://big.oisd.nl"
      enabled = true
    }
    "HaGeZi Threat Intelligence Feeds" = {
      url     = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt"
      enabled = true
    }
  }
}
