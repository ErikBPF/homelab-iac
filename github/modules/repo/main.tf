moved {
  from = github_repository.this["ha-toolcaller"]
  to   = github_repository.this["ha-harness"]
}

moved {
  from = github_actions_repository_permissions.this["ha-toolcaller"]
  to   = github_actions_repository_permissions.this["ha-harness"]
}

moved {
  from = github_workflow_repository_permissions.this["ha-toolcaller"]
  to   = github_workflow_repository_permissions.this["ha-harness"]
}

# Repo settings. Owns `allow_auto_merge` — the toggle that broke the
# codex/opencode update lanes at the `gh pr merge --auto` step ("Auto merge is
# not allowed for this repository") — plus the merge-strategy surface.
# prevent_destroy + archive_on_destroy guard against ever deleting a repo from
# a stray `destroy`.
resource "github_repository" "this" {
  for_each = var.repos

  name       = each.key
  visibility = each.value.visibility

  allow_auto_merge       = each.value.protect_main && each.value.allow_auto_merge
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
  repository      = github_repository.this[each.key].name
  enabled         = true
  allowed_actions = each.value.allowed_actions
}

# Default GITHUB_TOKEN scope + "Allow GitHub Actions to create and approve pull
# requests". The OFF state of can_approve_pull_request_reviews denied the
# create-pull-request step on codex/opencode. Codified so it can't drift off.
resource "github_workflow_repository_permissions" "this" {
  for_each                         = var.repos
  repository                       = github_repository.this[each.key].name
  default_workflow_permissions     = each.value.default_workflow_permissions
  can_approve_pull_request_reviews = each.value.can_approve_pull_requests
}

# Branch protection for each managed default branch.
resource "github_branch_protection" "main" {
  for_each = { for k, v in var.repos : k => v if v.protect_main }

  repository_id                   = github_repository.this[each.key].node_id
  pattern                         = each.value.branch_pattern
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  require_conversation_resolution = each.value.require_conversation_resolution

  dynamic "required_status_checks" {
    for_each = length(each.value.required_checks) == 0 ? [] : [true]
    content {
      strict   = true
      contexts = each.value.required_checks
    }
  }

  dynamic "required_pull_request_reviews" {
    for_each = each.value.require_pull_request_reviews ? [1] : []
    content {
      dismiss_stale_reviews           = each.value.dismiss_stale_reviews
      required_approving_review_count = 0
    }
  }
}

resource "github_app_installation_repository" "this" {
  for_each = var.app_installation_repositories
  provider = github.app_management

  installation_id = each.value.installation_id
  repository      = each.value.repository
}

resource "github_actions_secret" "this" {
  for_each = nonsensitive(var.actions_secrets)

  repository  = each.value.repository
  secret_name = each.value.secret_name
  value       = each.value.value
}
