include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//kv-secret"
}

inputs = {
  mount = "secret"
  name  = "platform/harbor/project-iam-manager"
  data = {
    HARBOR_PROJECT_IAM_MANAGER_USERNAME = "robot$homelab-iac-harbor-project-iam-manager"
    HARBOR_PROJECT_IAM_MANAGER_SECRET   = get_env("HARBOR_PROJECT_IAM_MANAGER_SECRET")
  }
  write_version = 2
}
