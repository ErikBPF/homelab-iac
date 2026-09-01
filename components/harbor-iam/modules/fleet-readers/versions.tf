terraform {
  required_version = ">= 1.11.0"

  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "3.12.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.10.1"
    }
  }
}
