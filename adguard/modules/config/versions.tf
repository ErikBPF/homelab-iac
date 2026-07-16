terraform {
  required_version = ">= 1.6"

  required_providers {
    adguardhome = {
      source  = "registry.terraform.io/ErikBPF/adguardhome"
      version = "= 0.1.7"
    }
  }
}
