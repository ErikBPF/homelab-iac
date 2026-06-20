terraform {
  required_version = ">= 1.6"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.17, < 1.0"
    }
  }
}
