include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/modules//dns"
}

# NetBird relay public IP (self-hosted overlay RFC §4/§8) — voyager's Oracle
# RESERVED public IP (oracle/modules/instance, reserve_public_ip). Written but
# NOT applied (Phase O, human op): placeholder until `terragrunt apply` in
# oracle/compute yields the real `reserved_public_ip` output. TEST-NET-3
# (RFC 5737) below is deliberately non-routable so this can't resolve to
# anything real until a human pastes the actual IP.
locals {
  # TODO(Phase-O, human op): replace with oracle/compute's `reserved_public_ip`
  # output once `reserve_public_ip = true` has been applied there.
  voyager_relay_ip = "203.0.113.10"
  # vanguard's current EPHEMERAL Oracle public IP (R3a relay2). Static TF record
  # — no ddclient/CF-token on the host; bump this on a vanguard reprovision,
  # same cadence as the console tools' OCID pins (just prints it via ip_vanguard).
  vanguard_relay_ip = "163.176.206.86"
}

# Cloudflare Tunnel CNAMEs (proxied) — the public edge for tunnel-exposed
# services. nanda/qualitransp removed 2026-06-29 with their tunnels (decommission).
inputs = {
  zone_id   = "2c4ac8f72b5661f3d360d4dececbd4ba"
  zone_name = "pastelariadev.com"

  records = {
    "ha.pastelariadev.com" = {
      type    = "CNAME"
      value   = "fe892a2a-213b-484c-948f-5b666be1fdd9.cfargotunnel.com"
      proxied = true
    }
    "whisper.pastelariadev.com" = {
      type    = "CNAME"
      value   = "fe892a2a-213b-484c-948f-5b666be1fdd9.cfargotunnel.com"
      proxied = true
    }

    # NetBird relay(s) — DNS-only / grey-cloud. Cloudflare's proxy can't carry
    # the relay's QUIC/UDP leg, and the relay terminates its own TLS (built-in
    # Let's Encrypt, RFC Q3) — proxying would break both. This is the ONLY
    # genuinely public NetBird surface (management/signal/dashboard stay
    # tailnet-only per §5, not Cloudflare records at all).
    "relay.pastelariadev.com" = {
      type    = "A"
      value   = local.voyager_relay_ip
      proxied = false
    }
    # relay2 (R3a): vanguard's public NetBird relay — a distinct failure domain
    # from voyager's relay. Static A at vanguard's ephemeral IP (see local);
    # DNS-only (grey) so QUIC/UDP + the relay's own Let's-Encrypt cert work.
    "relay2.pastelariadev.com" = {
      type    = "A"
      value   = local.vanguard_relay_ip
      proxied = false
    }
  }
}
