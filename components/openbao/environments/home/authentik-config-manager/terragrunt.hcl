include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//authentik-config-manager"
}

inputs = {
  authentik_config_manager_token = get_env("AUTHENTIK_CONFIG_MANAGER_TOKEN")
}
