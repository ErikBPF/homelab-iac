terraform {
  required_version = ">= 1.6"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
      configuration_aliases = [
        github.app_management,
      ]
    }
  }
}
