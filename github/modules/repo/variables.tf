variable "repos" {
  description = <<-EOT
    GitHub repositories managed by this component, keyed by repo name (owner is
    the provider `owner`). Defaults encode the fleet norm for the flake-input
    repos: public, all merge strategies, auto-merge on, Actions allowed, and a
    write GITHUB_TOKEN that may open/approve PRs — the two settings whose OFF
    state broke the codex/opencode auto-update lanes.
  EOT

  type = map(object({
    # Repo settings (github_repository).
    visibility             = optional(string, "public")
    allow_auto_merge       = optional(bool, true) # `gh pr merge --auto` needs this
    allow_merge_commit     = optional(bool, true)
    allow_squash_merge     = optional(bool, true)
    allow_rebase_merge     = optional(bool, true)
    delete_branch_on_merge = optional(bool, false)

    # Actions policy (github_actions_repository_permissions).
    allowed_actions = optional(string, "all") # all | local_only | selected

    # Default workflow token scope (github_workflow_repository_permissions).
    # can_approve_pull_requests=true == "Allow GitHub Actions to create and
    # approve pull requests"; the create-pull-request step fails without it.
    default_workflow_permissions = optional(string, "write") # read | write
    can_approve_pull_requests    = optional(bool, true)

    # Optional branch protection on main. Off by default — these repos have
    # none today, so leaving it off keeps the initial import a pure no-op.
    protect_main                    = optional(bool, false)
    required_checks                 = optional(list(string), [])
    require_conversation_resolution = optional(bool, false)
    require_pull_request_reviews    = optional(bool, false)
    dismiss_stale_reviews           = optional(bool, false)
  }))
}
