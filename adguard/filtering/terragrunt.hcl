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
    "*.k8s.pastelariadev.com"     = "192.168.10.210"
    "k8s.pastelariadev.com"       = "192.168.10.210"
    "*.homelab.pastelariadev.com" = "192.168.10.210"
    "homelab.pastelariadev.com"   = "192.168.10.210"
    "ha.pastelariadev.com"        = "192.168.10.210"
  }

  user_rules = []

  list_filters = {
    "AdGuard DNS filter" = {
      url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"
      enabled = true
    }
    "AdAway Default Blocklist" = {
      url     = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt"
      enabled = false
    }
  }
}
