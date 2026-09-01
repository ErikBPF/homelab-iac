include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = "${get_repo_root()}/components/harbor-iam/project-members-root.hcl"
}

terraform {
  source = "${get_repo_root()}/components/harbor-iam/modules/project-members"
}

inputs = {
  projects = toset(["dockerhub", "ghcr", "library", "lscr", "quay"])
}
