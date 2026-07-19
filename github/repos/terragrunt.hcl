include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//repo"
}

# Fleet repos whose GitHub settings we keep drift-proof: the flake-input repos
# consumed by desktop-nixos, plus the self-hosted Renovate runner. Values mirror
# current live state so the initial import is a zero-diff no-op; the defaults
# (see modules/repo/variables.tf) already encode the fleet norm, so most repos
# need no explicit fields. required_checks are the gates each repo's auto-merge
# lane waits on — recorded here for when protect_main is turned on later.
inputs = {
  repos = {
    codex-flake    = {}
    opencode-flake = {}
    hermes-flake   = {}
    kindle-dash = {
      allow_merge_commit              = false
      delete_branch_on_merge          = true
      default_workflow_permissions    = "read"
      can_approve_pull_requests       = false
      protect_main                    = true
      required_checks                 = ["validate", "secrets"]
      require_conversation_resolution = true
      require_pull_request_reviews    = true
      dismiss_stale_reviews           = true
    }
    servarr = {
      visibility                   = "private"
      allow_auto_merge             = false
      allow_merge_commit           = false
      allow_rebase_merge           = false
      delete_branch_on_merge       = true
      default_workflow_permissions = "read"
      can_approve_pull_requests    = false
    }
    # Renovate runner (RFC 2026-07-11). Private, so it overrides the public
    # default; brand-new repo, so its auto-merge is still off (GitHub default) —
    # expect the import plan to show +1 change flipping allow_auto_merge on.
    renovate-config = { visibility = "private" }
  }
}

# One-time state migration (config-driven import). Flip `disable = false`, run
# `terragrunt plan` (expect "3 to import, 0 to change" per repo), then
# `terragrunt apply`, then set `disable = true` again and commit. Import IDs:
# repo name for the three per-repo resources; "<repo>:main" for branch
# protection (unused until protect_main).
generate "imports" {
  path      = "imports_gen.tf"
  if_exists = "overwrite"
  disable   = true
  contents  = <<-EOT
    import {
      for_each = toset(["kindle-dash", "servarr"])
      to       = github_repository.this[each.key]
      id       = each.key
    }
    import {
      for_each = toset(["kindle-dash", "servarr"])
      to       = github_actions_repository_permissions.this[each.key]
      id       = each.key
    }
    import {
      for_each = toset(["kindle-dash", "servarr"])
      to       = github_workflow_repository_permissions.this[each.key]
      id       = each.key
    }
    import {
      to = github_branch_protection.main["kindle-dash"]
      id = "kindle-dash:main"
    }
  EOT
}
