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
  key_alias             = "cognee"
  models                = ["bge-m3", "bge-reranker-v2-m3", "parakeet-tdt-v3", "qwen-chat", "whisper-pt-br"]
  max_parallel_requests = 4
  rpm_limit             = 60
  tpm_limit             = 500000
  metadata = {
    consumer = "cognee"
    locality = "homelab-only"
  }
}
