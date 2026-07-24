variable "mount" {
  type = string
}

variable "name" {
  type = string
}

variable "data" {
  type      = map(string)
  sensitive = true
  ephemeral = true
}

variable "version" {
  type = number
}
