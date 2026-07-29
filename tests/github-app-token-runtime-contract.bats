#!/usr/bin/env bats

@test "GitHub app token refresh stays runtime-only" {
  script=bin/refresh-github-app-token.sh

  grep -Fq 'GITHUB_APP_MANAGEMENT_REFRESH_TOKEN' "$script"
  grep -Fq 'bao kv patch' "$script"
  grep -Fq 'printf %s "$access_token"' "$script"
  ! grep -Fq '.env.sops' "$script"
  ! grep -Fq 'sops set' "$script"
}

@test "Vault agent can rotate only the GitHub app token secret" {
  module=components/openbao/modules/runtime-secret-foundation/main.tf

  grep -Fq 'resource "vault_policy" "github_app_management"' "$module"
  grep -Fq 'secret/data/home/github-app-management' "$module"
  grep -Fq '"github-app-management"' "$module"
}
