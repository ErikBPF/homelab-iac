include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//policies"
}

# Default-deny baseline (RFC §6/§8): NetBird denies traffic between any two
# peers unless an explicit policy rule accepts it — the ONLY rule below is the
# admin-SSH exception, mirroring tailscale/acl's rule 1. Everything else is
# denied by omission. See DEFAULT-DENY.md alongside this file for the
# hand-readable export (belt-and-suspenders in case Terraform state is ever
# lost — a human can recreate this from the doc without re-deriving it).
#
# TODO(Phase-O, human op): a fresh NetBird account ships an implicit "Default"
# policy that allows ALL peers to reach each other — the Terraform provider
# does not manage that built-in resource. Disable or delete it by hand in the
# dashboard/API after bootstrap (WP2), otherwise it coexists with (and
# overrides the intent of) everything this unit creates.
#
# TODO(Phase-O, human op): after `terragrunt apply` in ../groups, run
# `terragrunt output group_ids` there and paste the real IDs below (this repo
# doesn't use cross-stack `dependency` blocks — see unifi/environments/home/wlan
# for the same hardcoded-ID-after-first-apply pattern). Until then this unit's
# group_ids map is a placeholder and won't apply cleanly — fine, WP4 is
# code-only.
locals {
  group_ids = {
    admins         = "TODO-paste-group-id-from-netbird-groups-output"
    fleet-servers  = "TODO-paste-group-id-from-netbird-groups-output"
    fleet-clients  = "TODO-paste-group-id-from-netbird-groups-output"
    netbird-relays = "TODO-paste-group-id-from-netbird-groups-output"
  }
}

inputs = {
  group_ids = local.group_ids

  policies = {
    "admin-ssh" = {
      description = "Admin devices (laptop/pathfinder/galaxy) reach every NetBird peer over the overlay -- mirrors tailscale/acl policy.hujson rule 1. This is the ONLY accept rule in the baseline; every other peer pair is denied by default."
      enabled     = true
      rules = [
        {
          name          = "admins-ssh-everywhere"
          description   = "Admin OpenSSH (:2222) into every fleet peer on the NetBird overlay."
          action        = "accept"
          protocol      = "tcp"
          bidirectional = false
          sources       = ["admins"]
          destinations  = ["fleet-servers", "fleet-clients", "netbird-relays"]
          ports         = ["2222"]
        }
      ]
    }
  }
}
