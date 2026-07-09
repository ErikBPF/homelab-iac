output "repo_node_ids" {
  description = "Map of repo name -> GitHub node_id."
  value       = { for k, r in github_repository.this : k => r.node_id }
}

output "workflow_permissions" {
  description = "Effective default workflow-token settings per repo."
  value = {
    for k, w in github_workflow_repository_permissions.this : k => {
      default_workflow_permissions     = w.default_workflow_permissions
      can_approve_pull_request_reviews = w.can_approve_pull_request_reviews
    }
  }
}
