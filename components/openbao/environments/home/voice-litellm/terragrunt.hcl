# Applied through an interactive owner plan. Excluded from unattended drift/apply
# until the scheduled runner credentials and zero-diff plan are verified.
include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

dependency "voice_key" {
  config_path = "../../../../litellm/environments/home/voice-key"
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//kv-secret"
}

inputs = {
  mount         = "secret"
  name          = "home/voice-litellm"
  data          = { VOICE_LITELLM_API_KEY = dependency.voice_key.outputs.key }
  write_version = 1
}
