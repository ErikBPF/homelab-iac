include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//acl"
}

# The tailnet policy lives as a versioned HuJSON file alongside this unit.
# tailscale_acl overwrites the WHOLE policy file — review the plan before apply.
inputs = {
  acl = file("${get_terragrunt_dir()}/policy.hujson")
}
