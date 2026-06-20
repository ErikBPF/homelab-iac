include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//dns"
}

# Imported from the live tailnet. 192.168.10.210 is the homelab resolver;
# 100.76.140.121 is a tailnet node.
inputs = {
  nameservers  = ["192.168.10.210", "100.76.140.121", "1.1.1.1", "8.8.8.8"]
  magic_dns    = true
  search_paths = []
}
