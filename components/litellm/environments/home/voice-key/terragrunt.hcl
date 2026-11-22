# Applied through an interactive owner plan. Excluded from unattended drift/apply
# until the scheduled runner credentials and zero-diff plan are verified.
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
  key_alias             = "svc-homelab-iac-voice-dictation-model-inference"
  models                = ["voice-transcribe", "voice-rewrite"]
  max_budget            = 25
  budget_duration       = "30d"
  max_parallel_requests = 2
  rpm_limit             = 20
  tpm_limit             = 1000000
  metadata = {
    consumer                    = "voice-dictation"
    locality                    = "local"
    store_prompts_in_spend_logs = "false"
  }
}
