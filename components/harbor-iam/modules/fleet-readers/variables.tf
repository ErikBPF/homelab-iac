variable "fleet_hosts" {
  type = set(string)
}

variable "disabled_hosts" {
  type    = set(string)
  default = []

  validation {
    condition     = length(setsubtract(var.disabled_hosts, var.fleet_hosts)) == 0
    error_message = "disabled_hosts must be present in the pinned fleet snapshot."
  }
}

variable "rotation_generation" {
  type    = number
  default = 1
}
