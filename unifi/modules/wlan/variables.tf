variable "wlans" {
  description = "SSIDs, keyed by name. Passphrases come from var.wlan_passphrases."
  type = map(object({
    security        = string # wpapsk | wpaeap | open
    user_group_id   = string
    network_id      = optional(string)
    wlan_band       = optional(string) # 2g | 5g | both
    wpa3_support    = optional(bool)
    wpa3_transition = optional(bool)
    pmf_mode        = optional(string) # disabled | optional | required
    hide_ssid       = optional(bool)
    is_guest        = optional(bool)
    ap_group_ids    = optional(set(string))
    no2ghz_oui      = optional(bool)
  }))
  default = {}
}

variable "wlan_passphrases" {
  description = "WPA pre-shared keys, keyed by SSID name. Sourced from .env."
  type        = map(string)
  default     = {}
  sensitive   = true
}
