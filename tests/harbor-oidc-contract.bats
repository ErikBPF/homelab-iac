#!/usr/bin/env bats

@test "purpose-named secret handoffs stay ignored" {
  git check-ignore -q authentik-admin-token.secrets.json
}

@test "Harbor IAM providers are pinned and credentials are purpose-named environment-only" {
  versions=components/harbor-iam/modules/oidc/versions.tf
  root=components/harbor-iam/root.hcl
  members_root=components/harbor-iam/project-members-root.hcl

  grep -Fq 'source  = "goauthentik/authentik"' "$versions"
  grep -Fq 'version = "2026.5.1"' "$versions"
  grep -Fq 'source  = "goharbor/harbor"' "$versions"
  grep -Fq 'version = "3.12.4"' "$versions"
  test "$(grep -Fc 'insecure = false' "$root")" -eq 2
  test "$(grep -Fc 'ephemeral = true' "$root")" -eq 4
  test "$(grep -Fc 'ephemeral = true' "$members_root")" -eq 2
  test "$(grep -Fc 'ephemeral = true' components/authentik/root.hcl)" -eq 1
  grep -Fq 'authentik_bootstrap_admin_token = get_env("AUTHENTIK_BOOTSTRAP_ADMIN_TOKEN")' \
    components/authentik/root.hcl
  grep -Eq 'authentik_config_manager_token[[:space:]]*=[[:space:]]*get_env\("AUTHENTIK_CONFIG_MANAGER_TOKEN"\)' "$root"
  grep -Eq 'harbor_bootstrap_admin_password[[:space:]]*=[[:space:]]*get_env\("HARBOR_BOOTSTRAP_ADMIN_PASSWORD"\)' "$root"
  grep -Eq 'harbor_project_iam_manager_secret[[:space:]]*=[[:space:]]*get_env\("HARBOR_PROJECT_IAM_MANAGER_SECRET", ""\)' "$root"
  grep -Fq 'harbor_project_iam_manager_username = get_env("HARBOR_PROJECT_IAM_MANAGER_USERNAME", "robot$homelab-iac-harbor-project-iam-manager")' "$members_root"
  grep -Eq 'harbor_project_iam_manager_secret[[:space:]]*=[[:space:]]*get_env\("HARBOR_PROJECT_IAM_MANAGER_SECRET"\)' "$members_root"
  grep -Fq 'constraints = "2026.5.1"' \
    components/authentik/environments/home/iac-access/.terraform.lock.hcl
  grep -Fq 'constraints = "3.12.4"' \
    components/harbor-iam/environments/home/production/.terraform.lock.hcl
  grep -Fq 'constraints = "3.12.4"' \
    components/harbor-iam/environments/home/project-members/.terraform.lock.hcl
  grep -Fq 'constraints = "5.10.1"' \
    components/openbao/environments/home/harbor-project-iam/.terraform.lock.hcl
  ! grep -Eq '(AUTHENTIK_CONFIG_MANAGER_TOKEN|HARBOR_BOOTSTRAP_ADMIN_PASSWORD|HARBOR_PROJECT_IAM_MANAGER_SECRET)[[:space:]]*=' "$root" "$members_root"
}

@test "Authentik Harbor client is strict, signed, scoped, and reader-bound" {
  module=components/harbor-iam/modules/oidc/main.tf

  grep -Eq 'matching_mode[[:space:]]*=[[:space:]]*"strict"' "$module"
  grep -Eq 'redirect_uri_type[[:space:]]*=[[:space:]]*"authorization"' "$module"
  grep -Eq 'url[[:space:]]*=[[:space:]]*"https://harbor.homelab.pastelariadev.com/c/oidc/callback"' "$module"
  ! grep -Fq 'https://harbor.homelab.pastelariadev.com/c/oidc/callback/' "$module"
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

@test "Harbor keeps local breakglass while day-two IAM maps readers only as project guests" {
  module=components/harbor-iam/modules/oidc/main.tf
  members=components/harbor-iam/modules/project-members/main.tf

  ! grep -Fq 'harbor_project_member_group' "$module"
  grep -Fq 'data "harbor_projects" "all"' "$members"
  ! grep -Fq 'data "harbor_project" "this"' "$members"
  grep -Fq 'for project in data.harbor_projects.all.projects' "$members"
  grep -Fq 'project_id = "/projects/${' "$members"
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
  test "$(grep -Fc 'role       = "guest"' "$members")" -eq 1
  grep -Fq 'projects = toset(["dockerhub", "library"])' \
    components/harbor-iam/environments/home/project-members/terragrunt.hcl
}

@test "Harbor bootstrap creates one explicit least-privilege project IAM manager" {
  module=components/harbor-iam/modules/oidc/main.tf

  grep -Fq 'resource "harbor_robot_account" "project_iam_manager"' "$module"
  grep -Eq 'name[[:space:]]*=[[:space:]]*"homelab-iac-harbor-project-iam-manager"' "$module"
  grep -Eq 'level[[:space:]]*=[[:space:]]*"system"' "$module"
  grep -Eq 'duration[[:space:]]*=[[:space:]]*365' "$module"
  grep -Eq 'secret_wo[[:space:]]*=[[:space:]]*var.harbor_project_iam_manager_secret_configured \? var.harbor_project_iam_manager_secret : null' "$module"
  grep -Eq 'secret_wo_version[[:space:]]*=[[:space:]]*var.harbor_project_iam_manager_secret_configured \? var.harbor_project_iam_manager_secret_version : null' "$module"
  grep -Fq 'resource = "project"' "$module"
  grep -Fq 'action   = "list"' "$module"
  for action in create read update list delete; do
    grep -Fq "action   = \"$action\"" "$module"
  done
  grep -Fq 'resource = "member"' "$module"
  grep -Fq 'namespace = permissions.value' "$module"
  grep -Fq 'default = ["dockerhub", "library"]' \
    components/harbor-iam/modules/oidc/variables.tf
  ! grep -Eq 'namespace[[:space:]]*=[[:space:]]*"\*"' "$module"
  ! grep -Eq 'resource[[:space:]]*=[[:space:]]*"(repository|artifact|robot|user-group)"' "$module"
  grep -Eq 'harbor_project_iam_manager_secret[[:space:]]*=[[:space:]]*get_env\("HARBOR_PROJECT_IAM_MANAGER_SECRET", ""\)' \
    components/harbor-iam/root.hcl
  grep -Eq 'harbor_project_iam_manager_secret_configured[[:space:]]*=[[:space:]]*get_env\("HARBOR_PROJECT_IAM_MANAGER_SECRET", ""\) != ""' \
    components/harbor-iam/root.hcl
  grep -Fq 'var.harbor_project_iam_manager_existing || var.harbor_project_iam_manager_secret_configured' "$module"
  grep -Fq 'var.harbor_project_iam_manager_secret_version == 2' "$module"
  test -x bin/harbor-iam-bootstrap
  grep -Fq 'HARBOR_PROJECT_IAM_MANAGER_EXISTING=true' bin/harbor-iam-bootstrap
}

@test "Harbor bootstrap runner fails closed for fresh or write-only state" {
  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  cat >"$fake_bin/terragrunt" <<'SH'
#!/usr/bin/env bash
case "$1 $2" in
  "state list") printf '%s\n' "${FAKE_STATE_LIST:-}" ;;
  "state show") printf '%s\n' "${FAKE_STATE_SHOW:-}" ;;
  *) printf '%s\n' "${HARBOR_PROJECT_IAM_MANAGER_EXISTING:-unset}" >"$FAKE_LOG" ;;
esac
SH
  chmod +x "$fake_bin/terragrunt"

  run env PATH="$fake_bin:$PATH" FAKE_LOG="$BATS_TEST_TMPDIR/log" \
    bin/harbor-iam-bootstrap plan
  [ "$status" -ne 0 ]

  run env PATH="$fake_bin:$PATH" FAKE_LOG="$BATS_TEST_TMPDIR/log" \
    FAKE_STATE_LIST=harbor_robot_account.project_iam_manager \
    FAKE_STATE_SHOW='secret_wo_version = 2' bin/harbor-iam-bootstrap plan
  [ "$status" -ne 0 ]

  run env PATH="$fake_bin:$PATH" FAKE_LOG="$BATS_TEST_TMPDIR/log" \
    FAKE_STATE_LIST=harbor_robot_account.project_iam_manager \
    bin/harbor-iam-bootstrap plan
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/log")" = true ]
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
  grep -Eq 'service_account_username[[:space:]]*=[[:space:]]*"svc-homelab-iac-authentik-config-manager"' "$unit"
  grep -Eq 'name[[:space:]]*=[[:space:]]*"rbac-homelab-iac-authentik-config-manager"' "$module"
  ! grep -Eq 'name[[:space:]]*=[[:space:]]*"homelab-iac"' "$module"
  grep -Eq 'operator_username[[:space:]]*=[[:space:]]*"erik"' "$unit"
  grep -Fq -- "--filter '!components/authentik/environments/home/iac-access'" \
    bin/drift-check.sh
  ! grep -Fq 'check "service_account_boundary"' "$module"
  grep -Fq 'precondition {' "$module"
  grep -Fq 'contains(["service_account", "internal_service_account"], data.authentik_user.service_account.type)' "$module"
  grep -Fq '!data.authentik_user.service_account.is_superuser' "$module"
}

@test "Harbor project membership has an independent day-two state" {
  grep -Eq '^components/harbor-iam/environments/home/project-members ' \
    tests/fixtures/state-keys.txt
  grep -Fq 'source = "${get_repo_root()}/components/harbor-iam/modules/project-members"' \
    components/harbor-iam/environments/home/project-members/terragrunt.hcl
}

@test "Harbor project IAM manager credential is write-only in OpenBao" {
  unit=components/openbao/environments/home/harbor-project-iam/terragrunt.hcl
  policy=components/openbao/modules/runtime-secret-foundation/main.tf

  grep -Fq 'modules//kv-secret' "$unit"
  grep -Eq 'name[[:space:]]*=[[:space:]]*"platform/harbor/project-iam-manager"' "$unit"
  grep -Fq 'HARBOR_PROJECT_IAM_MANAGER_USERNAME = "robot$homelab-iac-harbor-project-iam-manager"' "$unit"
  grep -Fq 'HARBOR_PROJECT_IAM_MANAGER_SECRET   = get_env("HARBOR_PROJECT_IAM_MANAGER_SECRET")' "$unit"
  grep -Eq 'write_version[[:space:]]*=[[:space:]]*2' "$unit"
  grep -Eq '^components/openbao/environments/home/harbor-project-iam ' \
    tests/fixtures/state-keys.txt
  grep -Fq 'resource "vault_policy" "harbor_project_iam_publisher"' "$policy"
  grep -Fq 'name   = "svc-homelab-iac-openbao-harbor-project-iam-publisher"' "$policy"
  iac_writer=$(sed -n '/resource "vault_policy" "iac_writer"/,/^}/p' "$policy")
  ! grep -Fq 'platform/harbor/project-iam-manager' <<<"$iac_writer"
  grep -Fq 'resource "vault_approle_auth_backend_role" "harbor_project_iam_publisher"' "$policy"
  grep -Fq 'token_policies = [vault_policy.harbor_project_iam_publisher.name]' "$policy"
}

@test "Harbor day-two OpenBao identity can read only its exact credential" {
  module=components/openbao/modules/runtime-secret-foundation/main.tf
  reader_policy=$(sed -n '/resource "vault_policy" "harbor_project_iam_reader"/,/^}/p' "$module")
  reader_role=$(sed -n '/resource "vault_approle_auth_backend_role" "harbor_project_iam_reader"/,/^}/p' "$module")

  grep -Fq 'resource "vault_policy" "harbor_project_iam_reader"' "$module"
  grep -Fq 'name   = "svc-homelab-iac-openbao-harbor-project-iam-reader"' <<<"$reader_policy"
  test "$(grep -Fc 'path "secret/data/platform/harbor/project-iam-manager"' <<<"$reader_policy")" -eq 1
  test "$(grep -Fc 'capabilities = ["read"]' <<<"$reader_policy")" -eq 1
  ! grep -Eq 'create|update|delete|list|\*' <<<"$reader_policy"
  grep -Fq 'resource "vault_approle_auth_backend_role" "harbor_project_iam_reader"' "$module"
  grep -Fq 'role_name      = "svc-homelab-iac-openbao-harbor-project-iam-reader"' <<<"$reader_role"
  grep -Fq 'token_policies = [vault_policy.harbor_project_iam_reader.name]' <<<"$reader_role"
  grep -Eq 'token_ttl[[:space:]]*=[[:space:]]*300' <<<"$reader_role"
  grep -Eq 'token_max_ttl[[:space:]]*=[[:space:]]*300' <<<"$reader_role"
  grep -Eq 'secret_id_ttl[[:space:]]*=[[:space:]]*7776000' <<<"$reader_role"
  test "$(grep -Fc 'secret_id_ttl  = 7776000' "$module")" -eq 4
}

@test "Harbor day-two wrapper resolves only its robot credential through AppRole" {
  script=bin/harbor-project-iam

  test -x "$script"
  grep -Fq 'secret/data/platform/harbor/project-iam-manager' "$script"
  grep -Fq 'env.OPENBAO_HARBOR_PROJECT_IAM_READER_ROLE_ID' "$script"
  grep -Fq 'env.OPENBAO_HARBOR_PROJECT_IAM_READER_SECRET_ID' "$script"
  grep -Fq 'auth/token/revoke-self' "$script"
  grep -Fq 'HARBOR_PROJECT_IAM_MANAGER_SECRET' "$script"
  grep -Fq 'components/harbor-iam/environments/home/project-members' "$script"
  ! grep -Eq 'HARBOR_(BOOTSTRAP_ADMIN|PASSWORD)|AUTHENTIK_' "$script"
}

@test "Harbor day-two wrapper revokes OpenBao and hides credentials from Terragrunt" {
  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  cat >"$fake_bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
url=${!#}
printf '%s\n' "$url" >>"$CURL_LOG"
case "$url" in
  */auth/approle/login)
    cat >/dev/null
    printf '%s\n' '{"auth":{"client_token":"temporary-openbao-token"}}'
    ;;
  */secret/data/platform/harbor/project-iam-manager)
    printf '%s\n' '{"data":{"data":{"HARBOR_PROJECT_IAM_MANAGER_USERNAME":"robot$homelab-iac-harbor-project-iam-manager","HARBOR_PROJECT_IAM_MANAGER_SECRET":"RobotSecret123"}}}'
    ;;
  */auth/token/revoke-self) ;;
  *) exit 2 ;;
esac
SH
  cat >"$fake_bin/terragrunt" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ -z ${OPENBAO_HARBOR_PROJECT_IAM_READER_ROLE_ID:-} ]]
[[ -z ${OPENBAO_HARBOR_PROJECT_IAM_READER_SECRET_ID:-} ]]
[[ $HARBOR_PROJECT_IAM_MANAGER_USERNAME == 'robot$homelab-iac-harbor-project-iam-manager' ]]
[[ $HARBOR_PROJECT_IAM_MANAGER_SECRET == RobotSecret123 ]]
printf '%s\n' "$*" >"$TERRAGRUNT_LOG"
SH
  chmod +x "$fake_bin/curl" "$fake_bin/terragrunt"

  run env \
    PATH="$fake_bin:$PATH" \
    CURL_LOG="$BATS_TEST_TMPDIR/curl.log" \
    TERRAGRUNT_LOG="$BATS_TEST_TMPDIR/terragrunt.log" \
    OPENBAO_HARBOR_PROJECT_IAM_READER_ROLE_ID=reader-role \
    OPENBAO_HARBOR_PROJECT_IAM_READER_SECRET_ID=reader-secret \
    bin/harbor-project-iam plan

  [ "$status" -eq 0 ]
  [[ $output != *reader-secret* ]]
  [[ $output != *RobotSecret123* ]]
  grep -Fq '/v1/secret/data/platform/harbor/project-iam-manager' "$BATS_TEST_TMPDIR/curl.log"
  grep -Fq '/v1/auth/token/revoke-self' "$BATS_TEST_TMPDIR/curl.log"
  grep -Fxq plan "$BATS_TEST_TMPDIR/terragrunt.log"
}

@test "Harbor OIDC state exposes no client secret output" {
  ! grep -R -q '^output ' components/harbor-iam
  ! grep -R -Eq 'client_secret[[:space:]]*=[[:space:]]*"[^$]' components/harbor-iam
}

@test "Harbor fleet readers are derived, pull-only, finite, and write-only" {
  module=components/harbor-iam/modules/fleet-readers/main.tf
  unit=components/harbor-iam/environments/home/fleet-readers/terragrunt.hcl

  grep -Eq 'fleet_hosts[[:space:]]*=[[:space:]]*toset\(keys\(local.fleet.hosts\)\)' "$unit"
  grep -Fq 'for_each = var.fleet_hosts' "$module"
  grep -Fq 'name        = "desktop-nixos-${each.key}-harbor-reader"' "$module"
  grep -Eq 'duration[[:space:]]*=[[:space:]]*365' "$module"
  grep -Fq 'disable     = contains(var.disabled_hosts, each.key)' "$module"
  grep -Fq 'secret_wo         = tostring(ephemeral.random_password.reader[each.key].result)' "$module"
  grep -Fq 'secret_wo_version = var.rotation_generation' "$module"
  test "$(grep -Fc 'action   = "pull"' "$module")" -eq 2
  test "$(grep -Fc 'resource = "repository"' "$module")" -eq 2
  grep -Fq 'namespace = "library"' "$module"
  grep -Fq 'namespace = "dockerhub"' "$module"
  ! grep -Eq 'namespace[[:space:]]*=[[:space:]]*"\*"' "$module"
  grep -Eq 'name[[:space:]]*=[[:space:]]*"fleet/harbor/readers/\$\{each.key\}"' "$module"
  grep -Eq 'data_json_wo[[:space:]]*=[[:space:]]*jsonencode\(\{' "$module"
  grep -Eq 'data_json_wo_version[[:space:]]*=[[:space:]]*var.rotation_generation' "$module"
  ! grep -R -q '^output ' components/harbor-iam/modules/fleet-readers
}

@test "only proven Harbor consumers receive exact-read OpenBao identities" {
  module=components/openbao/modules/runtime-secret-foundation/main.tf

  grep -Fq 'harbor_reader_consumers = toset(["discovery", "endeavour", "kepler"])' "$module"
  grep -Fq 'resource "vault_policy" "harbor_fleet_reader"' "$module"
  grep -Fq 'path "secret/data/fleet/harbor/readers/${each.key}"' "$module"
  grep -Fq 'resource "vault_approle_auth_backend_role" "harbor_fleet_reader"' "$module"
  grep -Fq 'role_name      = "svc-desktop-nixos-${each.key}-harbor-reader"' "$module"
  grep -Fq 'token_policies = [vault_policy.harbor_fleet_reader[each.key].name]' "$module"
  grep -Eq 'token_ttl[[:space:]]*=[[:space:]]*300' "$module"
  grep -Eq 'token_max_ttl[[:space:]]*=[[:space:]]*300' "$module"
  grep -Eq '^components/harbor-iam/environments/home/fleet-readers ' tests/fixtures/state-keys.txt
}
