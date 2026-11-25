#!/usr/bin/env bats

@test "GitHub app token refresh stays runtime-only" {
  script=bin/refresh-github-app-token.sh

  grep -Fq 'GITHUB_APP_MANAGEMENT_REFRESH_TOKEN' "$script"
  grep -Fq 'bao kv patch' "$script"
  grep -Fq 'printf %s "$access_token"' "$script"
  ! grep -Fq '.env.sops' "$script"
  ! grep -Fq 'sops set' "$script"
}

@test "App-scoped resources authenticate with app auth, not a refreshable token" {
  root=github/root.hcl
  unit=github/repos/terragrunt.hcl

  grep -Fq 'app_auth {' "$root"
  grep -Fq 'installation_id = var.github_app_installation_id' "$root"
  grep -Fq 'pem_file        = var.github_app_pem_file' "$root"
  ! grep -Fq 'github_app_management_token' "$root"
  grep -Fq 'GITHUB_APP_PEM_FILE' "$unit"
}

@test "Vault agent can rotate only the GitHub app token secret" {
  module=components/openbao/modules/runtime-secret-foundation/main.tf

  grep -Fq 'resource "vault_policy" "github_app_management"' "$module"
  grep -Fq 'secret/data/home/github-app-management' "$module"
  grep -Fq '"github-app-management"' "$module"
}
