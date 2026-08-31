#!/usr/bin/env bats

@test "purpose-named secret handoffs stay ignored" {
  git check-ignore -q authentik-admin-token.secrets.json
}

@test "Harbor IAM providers are pinned and credentials stay environment-only" {
  versions=components/harbor-iam/modules/oidc/versions.tf
  root=components/harbor-iam/root.hcl

  grep -Fq 'source  = "goauthentik/authentik"' "$versions"
  grep -Fq 'version = "2026.5.1"' "$versions"
  grep -Fq 'source  = "goharbor/harbor"' "$versions"
  grep -Fq 'version = "3.12.4"' "$versions"
  test "$(grep -Fc 'insecure = false' "$root")" -eq 2
  test "$(grep -Fc 'ephemeral = true' "$root")" -eq 3
  test "$(grep -Fc 'ephemeral = true' components/authentik/root.hcl)" -eq 1
  grep -Fq 'authentik_token = get_env("AUTHENTIK_TOKEN")' "$root"
  grep -Fq 'harbor_password = get_env("HARBOR_PASSWORD")' "$root"
  grep -Fq 'constraints = "2026.5.1"' \
    components/authentik/environments/home/iac-access/.terraform.lock.hcl
  grep -Fq 'constraints = "3.12.4"' \
    components/harbor-iam/environments/home/production/.terraform.lock.hcl
  ! grep -Eq '(AUTHENTIK_TOKEN|HARBOR_PASSWORD)[[:space:]]*=' "$root"
}

@test "Authentik Harbor client is strict, signed, scoped, and reader-bound" {
  module=components/harbor-iam/modules/oidc/main.tf

  grep -Eq 'matching_mode[[:space:]]*=[[:space:]]*"strict"' "$module"
  grep -Eq 'redirect_uri_type[[:space:]]*=[[:space:]]*"authorization"' "$module"
  grep -Eq 'url[[:space:]]*=[[:space:]]*"https://harbor.homelab.pastelariadev.com/c/oidc/callback/"' "$module"
  grep -Eq 'client_type[[:space:]]*=[[:space:]]*"confidential"' "$module"
  grep -Eq 'grant_types[[:space:]]*=[[:space:]]*\["authorization_code", "refresh_token"\]' "$module"
  grep -Fq 'authentication_flow = data.authentik_flow.authentication.id' "$module"
  grep -Eq 'issuer_mode[[:space:]]*=[[:space:]]*"per_provider"' "$module"
  grep -Eq 'access_code_validity[[:space:]]*=[[:space:]]*"minutes=1"' "$module"
  grep -Eq 'access_token_validity[[:space:]]*=[[:space:]]*"minutes=5"' "$module"
  grep -Eq 'refresh_token_validity[[:space:]]*=[[:space:]]*"hours=8"' "$module"
  grep -Eq 'signing_key[[:space:]]*=[[:space:]]*data.authentik_certificate_key_pair.signing.id' "$module"
  grep -Fq 'startswith("harbor-")' "$module"
  grep -Fq 'group  = data.authentik_group.readers.id' "$module"
  grep -Fq 'ak_user_has_authenticator(request.user, "totp")' "$module"
  grep -Fq 'ak_user_has_authenticator(request.user, "webauthn")' "$module"
  grep -Fq 'policy = authentik_policy_expression.mfa_enrolled.id' "$module"
}

@test "Harbor keeps local breakglass and maps readers only as project guests" {
  module=components/harbor-iam/modules/oidc/main.tf

  grep -Fq 'data "harbor_projects" "all"' "$module"
  ! grep -Fq 'data "harbor_project" "this"' "$module"
  grep -Fq 'for project in data.harbor_projects.all.projects' "$module"
  grep -Fq 'project_id = "/projects/${' "$module"
  grep -Eq 'auth_mode[[:space:]]*=[[:space:]]*"oidc_auth"' "$module"
  grep -Eq 'primary_auth_mode[[:space:]]*=[[:space:]]*false' "$module"
  grep -Eq 'oidc_verify_cert[[:space:]]*=[[:space:]]*true' "$module"
  grep -Eq 'oidc_auto_onboard[[:space:]]*=[[:space:]]*true' "$module"
  grep -Eq 'oidc_group_filter[[:space:]]*=[[:space:]]*"harbor-\*"' "$module"
  grep -Eq 'oidc_groups_claim[[:space:]]*=[[:space:]]*"groups"' "$module"
  grep -Eq 'oidc_user_claim[[:space:]]*=[[:space:]]*"preferred_username"' "$module"
  grep -Eq 'oidc_logout[[:space:]]*=[[:space:]]*true' "$module"
  grep -Fq 'oidc_client_secret_wo         = authentik_provider_oauth2.harbor.client_secret' "$module"
  grep -Fq 'oidc_client_secret_wo_version = 1' "$module"
  ! grep -q 'oidc_admin_group' "$module"
  test "$(grep -Fc 'role       = "guest"' "$module")" -eq 1
  grep -Fq 'projects = toset(["dockerhub", "library"])' \
    components/harbor-iam/environments/home/production/terragrunt.hcl
}

@test "Admin bootstrap grants no standing directory mutation capability" {
  unit=components/authentik/environments/home/iac-access/terragrunt.hcl
  module=components/authentik/modules/iac-access/main.tf

  grep -Fq 'authentik_core.view_group' "$unit"
  grep -Fq 'authentik_core.view_user' "$unit"
  grep -Fq 'authentik_policies_expression.add_expressionpolicy' "$unit"
  grep -Fq 'authentik_policies_expression.change_expressionpolicy' "$unit"
  grep -Fq 'authentik_policies_expression.delete_expressionpolicy' "$unit"
  grep -Fq 'authentik_policies_expression.view_expressionpolicy' "$unit"
  ! grep -Eq 'authentik_core\.(add|change|delete)_(group|user)' "$unit"
  grep -Fq 'is_superuser = false' "$module"
  grep -Eq 'service_account_username[[:space:]]*=[[:space:]]*"homelab-iac"' "$unit"
  grep -Eq 'operator_username[[:space:]]*=[[:space:]]*"erik"' "$unit"
  grep -Fq -- "--filter '!components/authentik/environments/home/iac-access'" \
    bin/drift-check.sh
}

@test "Harbor OIDC state exposes no client secret output" {
  ! grep -R -q '^output ' components/harbor-iam
  ! grep -R -Eq 'client_secret[[:space:]]*=[[:space:]]*"[^$]' components/harbor-iam
}
