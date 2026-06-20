terraform {
  required_version = ">= 1.6"

  required_providers {
    unifi = {
      source  = "filipowm/unifi"
      version = ">= 1.0, < 2.0"
    }
  }
}
