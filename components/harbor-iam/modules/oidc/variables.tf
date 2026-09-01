variable "reader_group_name" {
  type    = string
  default = "harbor-readers"
}

variable "harbor_project_iam_manager_secret_version" {
  type    = number
  default = 2
}

variable "harbor_project_iam_manager_projects" {
  type    = set(string)
  default = ["dockerhub", "ghcr", "k8s", "langfuse", "library", "lscr", "quay", "risingwave"]
}
