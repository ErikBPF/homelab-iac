terraform {
  required_version = ">= 1.6"

  required_providers {
    adguard = {
      source  = "gmichels/adguard"
      version = "= 1.7.0"
    }
  }
}
