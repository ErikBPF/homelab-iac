include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//dns"
}

# Imported from the live UDM (Phase 1).
inputs = {
  records = {
    "*.homelab.pastelariadev.com" = {
      type   = "A"
      record = "192.168.10.210"
    }
    "*.ai.pastelariadev.com" = {
      type   = "A"
      record = "192.168.10.112"
    }
  }
}
