#!/usr/bin/env bats

@test "S08 imports the existing OpenBao runtime-secret foundation" {
  module=components/openbao/modules/runtime-secret-foundation/main.tf
  imports=components/openbao/modules/runtime-secret-foundation/imports.tf

  grep -q 'resource "vault_mount" "secret"' "$module"
  grep -q 'resource "vault_auth_backend" "approle"' "$module"
  grep -q 'resource "vault_policy" "home_read"' "$module"
  grep -q 'resource "vault_policy" "iac_writer"' "$module"
  grep -q 'resource "vault_approle_auth_backend_role" "vault_agent"' "$module"
  grep -q 'resource "vault_approle_auth_backend_role" "iac_writer"' "$module"
  [ "$(grep -c '^import {' "$imports")" -eq 6 ]
}

@test "S08 preserves every live Vault Agent policy and TTL" {
  module=components/openbao/modules/runtime-secret-foundation/main.tf

  grep -Fq 'token_policies = ["discord-read", "home-read", "kindle-release-read"]' "$module"
  grep -Fq 'token_ttl      = 3600' "$module"
  grep -Fq 'token_max_ttl  = 14400' "$module"
}

@test "S08 bootstrap can use an ephemeral root token without storing it" {
  grep -q 'variable "vault_token"' components/openbao/root.hcl
  grep -q 'dynamic "auth_login"' components/openbao/root.hcl
  grep -Eq 'vault_token[[:space:]]*=[[:space:]]*get_env\\("VAULT_TOKEN", ""\\)' components/openbao/root.hcl
}
