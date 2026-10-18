include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//aster-identity-reader"
}

# Admin bootstrap only: the standing Authentik config-manager intentionally
# cannot create users, groups, or roles. No runtime token is issued here.
