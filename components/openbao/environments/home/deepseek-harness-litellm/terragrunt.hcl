include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

dependency "deepseek_harness_key" {
  config_path = "../../../../litellm/environments/home/deepseek-harness-key"
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//kv-secret"
}

inputs = {
  mount         = "secret"
  name          = "home/deepseek-harness-litellm"
  data          = { LITELLM_HOMELAB_API_KEY = dependency.deepseek_harness_key.outputs.key }
  write_version = 1
}
