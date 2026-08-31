variable "operator_username" {
  type = string
}
variable "service_account_username" {
  type = string
}

variable "reader_group_name" {
  type = string
}

variable "permissions" {
  type = set(string)
}
