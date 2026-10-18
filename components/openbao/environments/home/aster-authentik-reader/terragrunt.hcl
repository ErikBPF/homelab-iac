include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//kv-secret"
}

inputs = {
  mount = "secret"
  name  = "platform/aster/authentik-reader"
  data = {
    authentik_read_token = get_env("ASTER_AUTHENTIK_READ_TOKEN")
  }
  write_version = 1
}
