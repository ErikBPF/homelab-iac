include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//iac-access"
}

# Admin-only bootstrap. The resulting service token cannot mutate users/groups.
inputs = {
  service_account_username = "svc-homelab-iac-authentik-config-manager"
  operator_username        = "erik"
  reader_group_name        = "harbor-readers"
  permissions = toset([
    "authentik_core.view_application",
    "authentik_core.view_group",
    "authentik_core.view_user",
    "authentik_core.add_application",
    "authentik_core.change_application",
    "authentik_core.delete_application",
    "authentik_crypto.view_certificatekeypair",
    "authentik_flows.view_flow",
    "authentik_policies.add_policybinding",
    "authentik_policies.change_policybinding",
    "authentik_policies.delete_policybinding",
    "authentik_policies.view_policybinding",
    "authentik_policies_expression.add_expressionpolicy",
    "authentik_policies_expression.change_expressionpolicy",
    "authentik_policies_expression.delete_expressionpolicy",
    "authentik_policies_expression.view_expressionpolicy",
    "authentik_providers_oauth2.add_oauth2provider",
    "authentik_providers_oauth2.change_oauth2provider",
    "authentik_providers_oauth2.delete_oauth2provider",
    "authentik_providers_oauth2.view_oauth2provider",
    "authentik_providers_oauth2.add_scopemapping",
    "authentik_providers_oauth2.change_scopemapping",
    "authentik_providers_oauth2.delete_scopemapping",
    "authentik_providers_oauth2.view_scopemapping",
  ])
}
