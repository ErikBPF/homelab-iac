include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//model"
}

locals {
  manifest = jsondecode(file("${get_terragrunt_dir()}/models.json"))
}

inputs = {
  models                 = local.manifest.models
  yaml_model_list_cutoff = true
}
