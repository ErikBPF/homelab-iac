variable "key" {
  description = "Pre-minted key injected through TF_VAR_key; never persisted in state."
  type        = string
  sensitive   = true
  ephemeral   = true
}

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
