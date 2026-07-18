include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//key"
}

inputs = {
  key_alias             = "ha-harness"
  models                = ["ha-agent-qwen4b"]
  max_parallel_requests = 2
  rpm_limit             = 30
  tpm_limit             = 120000
  metadata = {
    consumer = "ha-harness"
    mode     = "dry-run"
  }
}
