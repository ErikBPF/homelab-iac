include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//repo"
}

# The flake-input repos consumed by desktop-nixos. Values mirror current live
# state so the initial import is a zero-diff no-op; the defaults (see
# modules/repo/variables.tf) already encode the fleet norm, so most repos need
# no explicit fields. required_checks are the gates each repo's auto-merge lane
# waits on — recorded here for when protect_main is turned on later.
inputs = {
  repos = {
    codex-flake    = {}
    opencode-flake = {}
    hermes-flake   = {}
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
      for_each = var.repos
      to       = github_repository.this[each.key]
      id       = each.key
    }
    import {
      for_each = var.repos
      to       = github_actions_repository_permissions.this[each.key]
      id       = each.key
    }
    import {
      for_each = var.repos
      to       = github_workflow_repository_permissions.this[each.key]
      id       = each.key
    }
  EOT
}
