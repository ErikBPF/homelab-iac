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
  models                = ["codex-gpt-6-astra", "deepseek-v4.1-flash", "glm-5.3-flash", "parakeet-tdt-v3", "whisper-pt-br"]
  max_budget            = 100
  budget_duration       = "7d"
  max_parallel_requests = 8
  rpm_limit             = 240
  tpm_limit             = 1000000
  metadata = {
    consumer   = "ocr-review"
    locality   = "desktop"
    controller = "desktop-nixos"
  }
}
