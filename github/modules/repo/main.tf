# Repo settings. Owns `allow_auto_merge` — the toggle that broke the
# codex/opencode update lanes at the `gh pr merge --auto` step ("Auto merge is
# not allowed for this repository") — plus the merge-strategy surface.
# prevent_destroy + archive_on_destroy guard against ever deleting a repo from
# a stray `destroy`.
resource "github_repository" "this" {
  for_each = var.repos

  name       = each.key
  visibility = each.value.visibility

  allow_auto_merge       = each.value.allow_auto_merge
  allow_merge_commit     = each.value.allow_merge_commit
  allow_squash_merge     = each.value.allow_squash_merge
  allow_rebase_merge     = each.value.allow_rebase_merge
  delete_branch_on_merge = each.value.delete_branch_on_merge

  archive_on_destroy = true

  lifecycle {
    prevent_destroy = true
    # Description/topics and the issue/wiki/project/download feature toggles are
    # managed in the GitHub UI, not here — this component owns only the
    # merge/auto-merge surface.
    ignore_changes = [
      description,
      homepage_url,
      topics,
      has_issues,
      has_wiki,
      has_projects,
      has_downloads,
    ]
  }
}

# Which actions / reusable workflows may run in the repo.
resource "github_actions_repository_permissions" "this" {
  for_each        = var.repos
  repository      = each.key
  enabled         = true
  allowed_actions = each.value.allowed_actions
}

# Default GITHUB_TOKEN scope + "Allow GitHub Actions to create and approve pull
# requests". The OFF state of can_approve_pull_request_reviews denied the
# create-pull-request step on codex/opencode. Codified so it can't drift off.
resource "github_workflow_repository_permissions" "this" {
  for_each                         = var.repos
  repository                       = each.key
  default_workflow_permissions     = each.value.default_workflow_permissions
  can_approve_pull_request_reviews = each.value.can_approve_pull_requests
}

# Opt-in branch protection on main (none of these repos have it today).
resource "github_branch_protection" "main" {
  for_each = { for k, v in var.repos : k => v if v.protect_main }

  repository_id  = github_repository.this[each.key].node_id
  pattern        = "main"
  enforce_admins = false

  required_status_checks {
    strict   = true
    contexts = each.value.required_checks
  }
}
