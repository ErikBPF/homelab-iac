#!/usr/bin/env bats

setup() {
  module=components/authentik/modules/openwebui-oidc
  unit=components/authentik/environments/home/openwebui-oidc/terragrunt.hcl
}

@test "OpenWebUI adopts provider3 without replacing application or client credentials" {
  test -f "$module/main.tf"
  grep -Fq 'provider_id = 3' "$module/main.tf"
  grep -Eq 'client_id[[:space:]]*=[[:space:]]*data\.authentik_provider_oauth2_config\.existing\.client_id' "$module/main.tf"
  grep -Fq 'id = "3"' "$module/main.tf"
  grep -Fq 'prevent_destroy = true' "$module/main.tf"
  ! grep -Eq 'client_secret[[:space:]]*=' "$module/main.tf"
  ! grep -Eq 'resource "authentik_(application|user|group|policy)' "$module/main.tf"
}

@test "OpenWebUI preserves observed token subject flow and mapping settings" {
  grep -Eq 'access_token_validity[[:space:]]*=[[:space:]]*"hours=1"' "$module/main.tf"
  grep -Eq 'sub_mode[[:space:]]*=[[:space:]]*"hashed_user_id"' "$module/main.tf"
  grep -Eq 'authorization_flow[[:space:]]*=[[:space:]]*"fa6bb8c8-e664-458d-89ec-c4c80a4d01f6"' "$module/main.tf"
  grep -Eq 'invalidation_flow[[:space:]]*=[[:space:]]*"d5a6979b-4d73-474e-958b-4885f5cd948d"' "$module/main.tf"
  grep -Eq 'signing_key[[:space:]]*=[[:space:]]*"a2f6e3ea-c944-4328-8ffd-e0a2b2beb529"' "$module/main.tf"
  test "$(grep -Ec '^    "[a-f0-9-]{36}",' "$module/main.tf")" -eq 3
}

@test "OpenWebUI publishes HTTPS before the compatibility callback is retired" {
  grep -Fq 'https://openwebui.homelab.pastelariadev.com/oauth/oidc/callback' "$module/main.tf"
  grep -Fq 'http://openwebui.homelab.pastelariadev.com/oauth/oidc/callback' "$module/main.tf"
  grep -Fq 'Temporary compatibility callback' "$module/main.tf"
  test "$(grep -Fc 'matching_mode     = "strict"' "$module/main.tf")" -eq 2
}

@test "OpenWebUI uses the existing config-manager identity with encrypted shared state" {
  grep -Fq 'get_env("AUTHENTIK_CONFIG_MANAGER_TOKEN")' "$unit"
  grep -Fq 'ephemeral = true' "$unit"
  grep -Fq 'sensitive = true' "$unit"
  grep -Fq '/_shared/root.hcl' "$unit"
  ! grep -Fq 'BOOTSTRAP_ADMIN' "$unit"
  ! grep -Fq 'insecure = true' "$unit"
}

@test "unadopted OpenWebUI unit stays outside unattended drift" {
  run grep -F -- "--filter '!components/authentik/environments/home/openwebui-oidc'" bin/drift-check.sh
  [ "$status" -eq 0 ]
}

@test "OpenWebUI preserves imported computed grant types" {
  ! grep -Eq '^[[:space:]]*grant_types[[:space:]]*=' "$module/main.tf"
}

@test "config-manager has dedicated write-only OpenBao storage and exact read role" {
  f=components/openbao/modules/authentik-config-manager/main.tf
  grep -Fq 'data_json_wo' "$f"
  grep -Fq 'iac/authentik-config-manager' "$f"
  grep -Fq 'secret/data/iac/authentik-config-manager' "$f"
  grep -Fq 'capabilities = ["read"]' "$f"
  ! grep -Fq 'capabilities = ["create"' "$f"
  grep -Fq 'ephemeral = true' components/openbao/modules/authentik-config-manager/variables.tf
  grep -Fq 'OPENBAO_AUTHENTIK_CONFIG_MANAGER_READER_ROLE_ID' bin/authentik-config-manager
  grep -Fq 'revoke-self' bin/authentik-config-manager
  grep -Fq 'components/authentik/environments/home/openwebui-oidc' bin/authentik-config-manager
  grep -Fq 'authentik-config-manager *args:' justfile
  grep -Fq -- "--filter '!components/openbao/environments/home/authentik-config-manager'" bin/drift-check.sh
}

@test "config-manager just wrapper revokes and fails closed without credential output" {
  python3 tests/authentik-config-manager.py
}
