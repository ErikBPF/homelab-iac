include "shared" {
  path = "${get_repo_root()}/_shared/root.hcl"
}

include "component" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//argus-reader"
}

# Manual bootstrap only: approve organization-wide Viewer before applying.
# Verified read-only /api/org on 2026-11-22: id=1, name=Main Org.
inputs = {
  org_id = 1
}
