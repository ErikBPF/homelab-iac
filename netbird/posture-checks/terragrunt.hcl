include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//posture-checks"
}

# TODO(Phase-O, human op): min_version is a placeholder — set it to whatever
# version desktop-nixos's WP1 netbird-client module actually pins once that
# lands, then keep the two in sync on every client bump.
inputs = {
  posture_checks = {
    "min-netbird-client" = {
      description = "Require a minimum NetBird client version before a peer is trusted (RFC §6)."
      netbird_version_check = {
        min_version = "0.30.0"
      }
    }
  }
}
