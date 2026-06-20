variable "reservations" {
  description = "Fixed-IP DHCP reservations, keyed by MAC address."
  type = map(object({
    name       = string
    fixed_ip   = string
    network_id = optional(string)
    note       = optional(string)
  }))
  default = {}
}
