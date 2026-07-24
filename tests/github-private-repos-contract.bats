#!/usr/bin/env bats

@test "private model and device repos use least-privilege Actions defaults" {
  config="$BATS_TEST_DIRNAME/../github/repos/terragrunt.hcl"

  for repo in ha-harness cosmo-notes; do
    grep -Eq "$repo[[:space:]]*=[[:space:]]*\\{" "$config"
    block="$(grep -A6 -E "$repo[[:space:]]*=[[:space:]]*\\{" "$config")"
    grep -Eq 'visibility[[:space:]]*=[[:space:]]*"private"' <<<"$block"
    grep -Eq 'default_workflow_permissions[[:space:]]*=[[:space:]]*"read"' <<<"$block"
    grep -Eq 'can_approve_pull_requests[[:space:]]*=[[:space:]]*false' <<<"$block"
  done
}

@test "Actions permissions wait for repository creation" {
  module="$BATS_TEST_DIRNAME/../github/modules/repo/main.tf"

  [ "$(grep -Ec 'repository[[:space:]]*=[[:space:]]*github_repository\.this\[each\.key\]\.name' "$module")" -eq 2 ]
}
