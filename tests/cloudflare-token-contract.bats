#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
  shopt -s nullglob
  TOKEN_UNITS=("$REPO_ROOT"/cloudflare/*-token/terragrunt.hcl)
  shopt -u nullglob
}

@test "every consumer token unit reuses the least-scope api-token module" {
  [ "${#TOKEN_UNITS[@]}" -gt 0 ]
  for unit in "${TOKEN_UNITS[@]}"; do
    grep -Fq 'modules//api-token' "$unit"
    ! grep -q 'resource "cloudflare_api_token"' "$unit"
  done
}

@test "swag and cert-manager use distinct consumer tokens" {
  local swag="$REPO_ROOT/cloudflare/swag-token/terragrunt.hcl"
  local certmanager="$REPO_ROOT/cloudflare/certmanager-token/terragrunt.hcl"

  test -f "$swag"
  test -f "$certmanager"

  local swag_name certmanager_name
  swag_name=$(sed -n 's/.*token_name *= *"\(.*\)".*/\1/p' "$swag")
  certmanager_name=$(sed -n 's/.*token_name *= *"\(.*\)".*/\1/p' "$certmanager")

  [ -n "$swag_name" ]
  [ -n "$certmanager_name" ]
  [ "$swag_name" != "$certmanager_name" ]
}

@test "consumer tokens grant zone DNS write and nothing account-scoped" {
  local module="$REPO_ROOT/cloudflare/modules/api-token/main.tf"

  grep -Fq 'zone["DNS Write"]' "$module"
  # Only a zone-scoped resource key is allowed; anything such as
  # "com.cloudflare.api.account.<id>" would grant account-wide access.
  ! grep -F 'api.account.' "$module" | grep -vF 'api.account.zone.'
  ! grep -qE 'zone\["(Access|Tunnel|SSL)' "$module"
  grep -Fq 'var.zone_read' "$module"
}

@test "token replacement creates before destroying" {
  grep -Fq 'create_before_destroy = true' "$REPO_ROOT/cloudflare/modules/api-token/main.tf"
  grep -Fq 'create_before_destroy = true' "$REPO_ROOT/cloudflare/modules/access/main.tf"
}
