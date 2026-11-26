#!/usr/bin/env bats

@test "private model and device repos use least-privilege Actions defaults" {
  config="$BATS_TEST_DIRNAME/../github/repos/terragrunt.hcl"

  for repo in agent-evals ha-harness cosmo-notes; do
    grep -Eq "$repo[[:space:]]*=[[:space:]]*\\{" "$config"
    block="$(grep -A6 -E "$repo[[:space:]]*=[[:space:]]*\\{" "$config")"
    grep -Eq 'visibility[[:space:]]*=[[:space:]]*"private"' <<<"$block"
    grep -Eq 'default_workflow_permissions[[:space:]]*=[[:space:]]*"read"' <<<"$block"
    grep -Eq 'can_approve_pull_requests[[:space:]]*=[[:space:]]*false' <<<"$block"
  done
}

@test "Actions permissions wait for repository creation" {
  module="$BATS_TEST_DIRNAME/../github/modules/repo/main.tf"

  run python3 - "$module" <<'PY'
import pathlib, re, sys

text = pathlib.Path(sys.argv[1]).read_text()
for kind, name in (
    ("github_actions_repository_permissions", "this"),
    ("github_workflow_repository_permissions", "this"),
    ("github_repository_vulnerability_alerts", "this"),
    ("github_repository_environment", "release"),
):
    block = re.search(rf'resource "{kind}" "{name}" \{{(?:(?!^}}).)*^}}', text, re.M | re.S)
    assert block, f"missing repository setting: {kind}.{name}"
    assert re.search(r"repository\s*=\s*github_repository\.this\[each\.key\]\.name", block.group()), kind
PY
  [ "$status" -eq 0 ]
}
