#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "every active GitHub repository is catalogued and protectable repos are protected" {
  run python3 - "$REPO_ROOT/github/repos/terragrunt.hcl" <<'PY'
import pathlib, re, sys

text = pathlib.Path(sys.argv[1]).read_text()
repos = text.split("  repos = {", 1)[1].split("\n  }\n\n  app_installation_repositories", 1)[0]
expected = {
    "agentmemory", "ai-server", "codex-flake", "datafoundation-support-scripts",
    "desktop-nixos", "hermes-flake", "hermes-skills", "home-assistant-config",
    "homelab-gitops", "homelab-iac", "kindle-dash", "klipper-biqu",
    "nanda_colors", "nstech-dev-technical-test", "nstech-mdm-technical-test",
    "opencode-flake", "renovate-config", "romozinha", "sail", "sail-dev",
    "servarr", "spicyphus", "terraform-provider-adguardhome",
    "terraform-provider-litellm", "terraform-provider-netbird", "vault",
    "zmk-config-chary",
}
declared = set(re.findall(r'^\s{4}([a-zA-Z0-9_-]+)\s+=\s+\{', repos, re.M))
assert declared == expected, (sorted(expected - declared), sorted(declared - expected))
private = {name for name in expected if re.search(
    rf"^    {re.escape(name)} = \{{(?:(?!^    \}}).)*visibility\s*=\s*\"private\"",
    repos, re.M | re.S,
)}
for name in expected:
    block = re.search(rf"^    {re.escape(name)} = \{{(?:(?!^    \}}).)*^    \}}", repos, re.M | re.S).group()
    assert f"protect_main = {'false' if name in private else 'true'}" in re.sub(r"\s+", " ", block), name
assert len(private) == 12
PY
  [ "$status" -eq 0 ]
}

@test "branch protection denies bypass-prone mutations" {
  run python3 - "$REPO_ROOT/github/modules/repo/main.tf" <<'PY'
import pathlib, re, sys

text = pathlib.Path(sys.argv[1]).read_text()
for name, value in (
    ("enforce_admins", "true"),
    ("require_conversation_resolution", "each.value.require_conversation_resolution"),
    ("allows_deletions", "false"),
    ("allows_force_pushes", "false"),
    ("required_approving_review_count", "0"),
):
    assert re.search(rf"{name}\s*=\s*{re.escape(value)}", text), name
PY
  [ "$status" -eq 0 ]
}

@test "repository defaults remove merged branches and unsafe merge modes" {
  run python3 - "$REPO_ROOT/github/modules/repo/variables.tf" <<'PY'
import pathlib, sys

text = pathlib.Path(sys.argv[1]).read_text()
for required in (
    'allow_merge_commit     = optional(bool, false)',
    'allow_squash_merge     = optional(bool, true)',
    'allow_rebase_merge     = optional(bool, false)',
    'delete_branch_on_merge = optional(bool, true)',
    'default_workflow_permissions = optional(string, "read")',
    'can_approve_pull_requests    = optional(bool, false)',
):
    assert required in text, required
PY
  [ "$status" -eq 0 ]
}

@test "migration imports only the 21 missing workflow permission resources" {
  run python3 - "$REPO_ROOT/github/repos/terragrunt.hcl" <<'PY'
import pathlib, re, sys

text = pathlib.Path(sys.argv[1]).read_text()
imports = text.split('generate "imports"', 1)[1]
assert "disable   = false" in imports
assert imports.count("import {") == 1
assert "github_workflow_repository_permissions.this[each.key]" in imports
assert "github_repository.this[each.key]" not in imports
assert "github_actions_repository_permissions.this[each.key]" not in imports
assert "github_branch_protection.main[each.key]" not in imports
names = re.findall(r'"([a-z0-9_-]+)"', imports.split("toset([", 1)[1].split("])", 1)[0])
assert len(names) == 21, names
PY
  [ "$status" -eq 0 ]
}
