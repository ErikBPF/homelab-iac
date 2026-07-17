terraform {
  required_version = ">= 1.6"

  required_providers {
    adguardhome = {
      source  = "registry.terraform.io/ErikBPF/adguardhome"
      version = "= 0.1.7"
    }
  }
}

variable "host" { type = string }
variable "cache_size" { type = number }

provider "adguardhome" {
  host     = var.host
  username = "fixture"
  password = "fixture-only"
  scheme   = "http"
}

resource "adguardhome_config" "fixture" {
  dns = {
    upstream_dns = ["1.1.1.1"]
    cache_size   = var.cache_size
  }
}
