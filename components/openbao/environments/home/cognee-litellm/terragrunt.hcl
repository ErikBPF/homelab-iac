include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

dependency "cognee_key" {
  config_path = "../../../../litellm/environments/home/cognee-key"
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//kv-secret"
}

inputs = {
  mount         = "secret"
  name          = "lab/cognee-litellm"
  data          = { LLM_API_KEY = dependency.cognee_key.outputs.key }
  write_version = 1
}
