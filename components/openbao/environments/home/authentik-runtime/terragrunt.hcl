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
  name  = "platform/authentik"
  data = {
    AUTHENTIK_SECRET_KEY           = get_env("AUTHENTIK_SECRET_KEY")
    AUTHENTIK_POSTGRESQL__PASSWORD = get_env("AUTHENTIK_POSTGRESQL_PASSWORD")
  }
  write_version = 1
}
