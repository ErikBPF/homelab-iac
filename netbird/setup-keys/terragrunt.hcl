include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//setup-keys"
}

# Machine enrollment bypasses user MFA by design (RFC §6a) — kept ephemeral,
# usage-limited, and group-scoped; gate joins with peer approval as well
# (account-level; the provider's netbird_account_settings.peer_approval_enabled
# is documented "(Cloud only)" for the current provider version — verify
# against the self-hosted API in Phase O before relying on it, and if it
# doesn't apply, enable peer approval by hand in the dashboard instead).
#
# TODO(Phase-O, human op): after `terragrunt apply` in ../groups, run
# `terragrunt output group_ids` there and paste the real "fleet-servers" ID
# below (this repo doesn't use cross-stack `dependency` blocks — see
# unifi/environments/home/wlan for the same hardcoded-ID-after-first-apply
# pattern). Until then this unit's group_ids map is a placeholder and won't
# apply cleanly — fine, WP4 is code-only.
locals {
  group_ids = {
    "fleet-servers" = "TODO-paste-group-id-from-netbird-groups-output"
  }
}

inputs = {
  group_ids = local.group_ids

  setup_keys = {
    "fleet-server-bootstrap" = {
      type           = "reusable"
      expiry_seconds = 604800 # 7d — one bootstrap window, not a standing credential
      usage_limit    = 5      # TODO(Phase-O): size to the real host count once known
      ephemeral      = false
      auto_groups    = ["fleet-servers"]
    }
  }
}
