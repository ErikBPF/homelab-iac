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
  key_alias             = "svc-homelab-iac-pala-note-asr"
  models                = ["parakeet-tdt-v3"]
  max_parallel_requests = 1
  rpm_limit             = 60
  tpm_limit             = 60000
  metadata = {
    consumer = "pala-note"
    mode     = "asr"
  }
}
