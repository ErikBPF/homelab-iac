variable "key_alias" {
  type = string
}

variable "models" {
  type = list(string)
}

variable "max_parallel_requests" {
  type = number
}

variable "rpm_limit" {
  type = number
}

variable "tpm_limit" {
  type = number
}

variable "metadata" {
  type = map(string)
}
