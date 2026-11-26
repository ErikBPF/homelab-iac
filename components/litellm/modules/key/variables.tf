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

variable "budget_duration" {
  description = "Budget window for the key. LiteLLM rejects an empty value on update, and the provider sends one when this input is absent."
  type        = string
  default     = "30d"
}

variable "metadata" {
  type = map(string)
}
