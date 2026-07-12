include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//nameservers"
}

# Split-DNS for the homelab zone over the overlay (RFC §3/§8.4): NetBird peers
# resolve *.homelab.pastelariadev.com via discovery's resolver, everything else
# via their normal DNS. Mirrors the Tailscale MagicDNS split-DNS already wired in
# tailscale/acl (discovery + vanguard CoreDNS answer the same zone).
#
# `primary = false` + `domains = [zone]` => a match-domain (split) resolver, NOT
# the peers' default DNS. discovery answers *.homelab -> LAN IPs (192.168.10.x).
#
# REACHABILITY CAVEAT (honest — same spirit as the other units' TODOs): a peer on
# the home LAN reaches 192.168.10.210:53 directly, so split-DNS is effective for
# on-LAN overlay peers immediately. A REMOTE (off-LAN) overlay peer additionally
# needs (a) discovery reachable over the overlay to hit the resolver and (b) a
# route to 192.168.10.0/24 for the answers to be usable — that is the ../routes
# decision (deferred: needs a routing peer ON the LAN + an explicit
# expose-the-LAN-subnet decision; discovery is the control-plane server, not a
# client peer, so it cannot be the router as-is).
#
# TODO(Phase-O, human op): after `terragrunt apply` in ../groups, run
# `terragrunt output group_ids` there and paste the real IDs below (this repo
# doesn't use cross-stack `dependency` blocks — same hardcoded-ID-after-first-
# apply pattern as ../policies and unifi/environments/home/wlan). Until then the
# group_ids map is a placeholder and won't apply cleanly — fine, code-only.
locals {
  group_ids = {
    fleet-servers = "d99f2h8i7llg00bf0ki0"
    fleet-clients = "d99f2h8i7llg00bf0kj0"
  }
}

inputs = {
  group_ids = local.group_ids

  nameserver_groups = {
    "homelab-split-dns" = {
      description = "Resolve *.homelab.pastelariadev.com via discovery (split-DNS), mirroring Tailscale MagicDNS."
      primary     = false
      domains     = ["homelab.pastelariadev.com"]
      nameservers = [
        { ip = "192.168.10.210", ns_type = "udp", port = 53 },
      ]
      groups = ["fleet-servers", "fleet-clients"]
    }
  }
}
