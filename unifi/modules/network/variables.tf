variable "networks" {
  description = "VLANs / networks, keyed by name."
  type = map(object({
    purpose          = string           # corporate | guest | wan | vlan-only
    subnet           = optional(string) # CIDR, e.g. "192.168.10.1/24"
    vlan_id          = optional(number)
    network_group    = optional(string, "LAN")
    multicast_dns    = optional(bool)
    dhcp_enabled     = optional(bool, true)
    dhcp_start       = optional(string)
    dhcp_stop        = optional(string)
    dhcp_lease       = optional(number)
    dhcp_dns         = optional(list(string))
    dhcp_v6_dns_auto = optional(bool)
    dhcp_v6_dns      = optional(list(string))
    domain_name      = optional(string)
    igmp_snooping    = optional(bool)
  }))
  default = {}
}
