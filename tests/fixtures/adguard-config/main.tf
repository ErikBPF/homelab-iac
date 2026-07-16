terraform {
  required_version = ">= 1.6"

  required_providers {
    adguard = {
      source  = "gmichels/adguard"
      version = "= 1.7.0"
    }
  }
}

variable "host" { type = string }
variable "cache_size" { type = number }

provider "adguard" {
  host     = var.host
  username = "fixture"
  password = "fixture-only"
  scheme   = "http"
}

resource "adguard_config" "fixture" {
  dns = {
    upstream_dns = ["1.1.1.1"]
    cache_size   = var.cache_size
  }

  dhcp = {
    enabled   = false
    interface = "eth0"
    ipv4_settings = {
      gateway_ip     = "192.0.2.1"
      subnet_mask    = "255.255.255.0"
      range_start    = "192.0.2.10"
      range_end      = "192.0.2.20"
      lease_duration = 3600
    }
  }
}
