data "harbor_projects" "all" {}

resource "harbor_project_member_group" "readers" {
  for_each = var.projects

  project_id = "/projects/${[
    for project in data.harbor_projects.all.projects : project.project_id
    if project.name == each.key
  ][0]}"
  group_name = var.reader_group_name
  role       = "guest"
  type       = "oidc"
}
