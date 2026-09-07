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
  key_alias             = "svc-homelab-iac-deepseek-harness-model-inference"
  models                = ["deepseek-v4-flash", "deepseek-v4-pro", "qwen-chat"]
  max_budget            = 25
  budget_duration       = "30d"
  max_parallel_requests = 8
  rpm_limit             = 120
  tpm_limit             = 1000000
  metadata = {
    consumer = "deepseek-harness"
    locality = "mixed"
  }
}
