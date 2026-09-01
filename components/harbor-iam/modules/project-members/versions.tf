terraform {
  required_version = ">= 1.11.0"

  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "3.12.4"
    }
  }
}
