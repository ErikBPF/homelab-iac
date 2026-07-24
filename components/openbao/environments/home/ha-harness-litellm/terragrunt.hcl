include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

dependency "ha_harness_key" {
  config_path = "../../../../litellm/environments/home/ha-harness-key"
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//kv-secret"
}

inputs = {
  mount         = "secret"
  name          = "home/ha-harness-litellm"
  data          = { LITELLM_API_KEY = dependency.ha_harness_key.outputs.key }
  write_version = 1
}
