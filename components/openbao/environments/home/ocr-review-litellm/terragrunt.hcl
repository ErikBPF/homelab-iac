include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

dependency "ocr_review_key" {
  config_path = "../../../../litellm/environments/home/ocr-review-key"
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//kv-secret"
}

inputs = {
  mount         = "secret"
  name          = "home/ocr-review-litellm"
  data          = { LITELLM_OCR_API_KEY = dependency.ocr_review_key.outputs.key }
  write_version = 1
}
