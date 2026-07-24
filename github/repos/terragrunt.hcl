include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//repo"
}

locals {
  kindle_release_app_id          = get_env("KINDLE_RELEASE_APP_ID", "")
  kindle_release_installation_id = get_env("KINDLE_RELEASE_INSTALLATION_ID", "")
  kindle_release_private_key_b64 = get_env("KINDLE_RELEASE_PRIVATE_KEY_B64", "")
  kindle_release_ready = alltrue([
    local.kindle_release_app_id != "",
    local.kindle_release_installation_id != "",
    local.kindle_release_private_key_b64 != "",
  ])
}

# Every active repository owned by ErikBPF. Actions token overrides preserve
# live automation capabilities; all other settings use hardened defaults.
inputs = {
  repos = {
    agentmemory = {
      protect_main = true
    }
    ai-server = {
      visibility   = "private"
      protect_main = false # GitHub Free does not support private branch protection.
    }
    codex-flake = {
      protect_main                 = true
      required_checks              = ["check", "package-build"]
      default_workflow_permissions = "write"
      can_approve_pull_requests    = true
    }
    cosmo-notes = {
      visibility                   = "private"
      allow_auto_merge             = false
      protect_main                 = false
      default_workflow_permissions = "read"
      can_approve_pull_requests    = false
    }
    datafoundation-support-scripts = {
      visibility   = "private"
      protect_main = false
    }
    desktop-nixos = {
      protect_main = true
      required_checks = [
        "lint", "flake-lock", "k3s-smoke", "eval (pathfinder)",
        "eval (laptop)", "eval (orion)", "eval (discovery)", "eval (kepler)",
      ]
    }
    hermes-flake = {
      protect_main = true
      required_checks = [
        "build (x86_64-linux, ubuntu-latest)",
        "build (aarch64-linux, ubuntu-24.04-arm)",
      ]
      default_workflow_permissions = "write"
      can_approve_pull_requests    = true
    }
    hermes-skills = {
      visibility   = "private"
      protect_main = false
    }
    ha-harness = {
      visibility                   = "private"
      allow_auto_merge             = false
      protect_main                 = false
      default_workflow_permissions = "read"
      can_approve_pull_requests    = false
    }
    home-assistant-config = {
      visibility   = "private"
      protect_main = false
    }
    homelab-gitops = {
      visibility   = "private"
      protect_main = false
    }
    homelab-iac = {
      protect_main    = true
      required_checks = ["lint"]
    }
    kindle-dash = {
      default_workflow_permissions = "read"
      can_approve_pull_requests    = false
      protect_main                 = true
      required_checks              = ["validate", "secrets"]
    }
    klipper-biqu = {
      visibility   = "private"
      protect_main = false
    }
    nanda_colors = {
      visibility   = "private"
      protect_main = false
    }
    nstech-dev-technical-test = {
      protect_main                 = true
      default_workflow_permissions = "write"
      can_approve_pull_requests    = true
    }
    nstech-mdm-technical-test = {
      protect_main = true
    }
    opencode-flake = {
      protect_main                 = true
      required_checks              = ["check", "package-build"]
      default_workflow_permissions = "write"
      can_approve_pull_requests    = true
    }
    renovate-config = {
      visibility                   = "private"
      protect_main                 = false
      default_workflow_permissions = "write"
      can_approve_pull_requests    = true
    }
    romozinha = {
      visibility   = "private"
      protect_main = false
    }
    sail = {
      protect_main = true
    }
    sail-dev = {
      visibility                   = "private"
      protect_main                 = false
      default_workflow_permissions = "write"
    }
    servarr = {
      visibility                   = "private"
      allow_auto_merge             = false
      protect_main                 = false
      default_workflow_permissions = "read"
      can_approve_pull_requests    = false
    }
    spicyphus = {
      protect_main = true
    }
    terraform-provider-adguardhome = {
      protect_main    = true
      required_checks = ["unit", "generated-docs"]
    }
    terraform-provider-litellm = {
      protect_main = true
    }
    terraform-provider-netbird = {
      protect_main = true
    }
    vault = {
      visibility   = "private"
      protect_main = false
    }
    zmk-config-chary = {
      branch_pattern               = "master"
      protect_main                 = true
      default_workflow_permissions = "write"
      can_approve_pull_requests    = true
    }
  }

  app_installation_repositories = local.kindle_release_ready ? {
    kindle-release-servarr = {
      installation_id = local.kindle_release_installation_id
      repository      = "servarr"
    }
  } : {}

  actions_secrets = local.kindle_release_ready ? {
    kindle-release-app-id = {
      repository  = "kindle-dash"
      secret_name = "KINDLE_RELEASE_APP_ID"
      value       = local.kindle_release_app_id
    }
    kindle-release-private-key = {
      repository  = "kindle-dash"
      secret_name = "KINDLE_RELEASE_PRIVATE_KEY"
      value       = base64decode(local.kindle_release_private_key_b64)
    }
  } : {}
}
