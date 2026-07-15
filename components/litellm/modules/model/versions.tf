terraform {
  required_version = ">= 1.8.0"

  required_providers {
    litellm = {
      source  = "registry.terraform.io/ErikBPF/litellm"
      version = "1.1.1"
    }
  }
}
