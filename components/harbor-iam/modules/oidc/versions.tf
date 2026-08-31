terraform {
  required_version = ">= 1.11.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.5.1"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.12.4"
    }
  }
}
