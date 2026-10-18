include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//scoped-key"
}

inputs = {
  key_alias             = "svc-homelab-iac-aster-model-inference"
  models                = ["deepseek-v4.1-flash"]
  max_budget            = 25
  budget_duration       = "30d"
  max_parallel_requests = 8
  rpm_limit             = 120
  tpm_limit             = 1000000
  metadata = {
    consumer = "aster"
    locality = "cloud"
  }
}
