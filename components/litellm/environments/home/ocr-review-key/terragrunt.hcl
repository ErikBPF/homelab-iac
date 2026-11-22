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
  key_alias             = "svc-homelab-iac-ocr-review-model-inference"
  models                = ["glm-5.3-flash", "deepseek-v4.1-flash"]
  max_budget            = 25
  budget_duration       = "30d"
  max_parallel_requests = 8
  rpm_limit             = 240
  tpm_limit             = 1000000
  metadata = {
    consumer   = "ocr-review"
    locality   = "desktop"
    controller = "desktop-nixos"
  }
}
