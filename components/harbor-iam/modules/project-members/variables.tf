variable "projects" {
  type = set(string)
}

variable "reader_group_name" {
  type    = string
  default = "harbor-readers"
}
