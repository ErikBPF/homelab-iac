#!/usr/bin/env bats

@test "Aster has a separate non-superuser Authentik identity with read-only user and group rights" {
  module=components/authentik/modules/aster-identity-reader/main.tf
  unit=components/authentik/environments/home/aster-identity-reader/terragrunt.hcl
  test -f "$module"
  test -f "$unit"
  grep -Fq 'username = "svc-aster-authentik-identity-reader"' "$module"
  grep -Fq 'type     = "service_account"' "$module"
  grep -Fq 'is_superuser = false' "$module"
  grep -Fq 'authentik_core.view_user' "$module"
  grep -Fq 'authentik_core.view_group' "$module"
  ! grep -Eq 'authentik_.*\.(add|change|delete)_' "$module"
  ! grep -Fq 'resource "authentik_token"' "$module"
}

@test "Aster Authentik token stays out of Terraform state and uses one OpenBao path" {
  unit=components/openbao/environments/home/aster-authentik-reader/terragrunt.hcl
  policy=components/openbao/modules/runtime-secret-foundation/main.tf
  test -f "$unit"
  grep -Fq 'modules//kv-secret' "$unit"
  grep -Fq 'name  = "platform/aster/authentik-reader"' "$unit"
  grep -Fq 'authentik_read_token = get_env("ASTER_AUTHENTIK_READ_TOKEN")' "$unit"
  grep -Fq 'data_json_wo' components/openbao/modules/kv-secret/main.tf
  grep -Fq 'ephemeral = true' components/openbao/modules/kv-secret/variables.tf
  grep -Fq 'path "secret/data/platform/aster/authentik-reader" {' "$policy"
  grep -Fq 'vault_approle_auth_backend_role" "aster_authentik_reader_publisher"' "$policy"
  publisher_policy=$(sed -n '/resource "vault_policy" "aster_authentik_reader_publisher"/,/^}/p' "$policy")
  ! grep -Fq 'secret/metadata/' <<<"$publisher_policy"
  publisher_role=$(sed -n '/resource "vault_approle_auth_backend_role" "aster_authentik_reader_publisher"/,/^}/p' "$policy")
  grep -Eq 'secret_id_ttl[[:space:]]*=[[:space:]]*86400' <<<"$publisher_role"
  ! grep -Fq 'secret/data/platform/aster/*' "$policy"
  ! grep -Rq 'output ' components/openbao/modules/kv-secret
}

@test "Aster namespace has its own exact-path OpenBao read identity" {
  policy=components/openbao/modules/runtime-secret-foundation/main.tf
  grep -Fq 'resource "vault_policy" "aster_authentik_reader_consumer"' "$policy"
  grep -Fq 'path "secret/data/platform/aster/authentik-reader" {' "$policy"
  grep -Fq 'capabilities = ["read"]' "$policy"
  grep -Fq 'resource "vault_approle_auth_backend_role" "aster_authentik_reader_consumer"' "$policy"
  grep -Fq 'token_policies = [vault_policy.aster_authentik_reader_consumer.name]' "$policy"
  ! grep -Fq 'secret/data/platform/*' "$policy"
}
