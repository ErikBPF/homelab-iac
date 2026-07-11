# voyager — the Always-Free Ampere A1 offsite backup receiver.
# After apply: take the `public_ip` output → set ip_voyager in
# desktop-nixos/justfile → `just deploy-voyager` to convert Ubuntu → NixOS.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../modules/instance"
}

locals {
  # SSH key injected for the 'ubuntu' user so nixos-anywhere can reach the host
  # before cutover. Override the path with OCI_SSH_PUBKEY_FILE if needed.
  ssh_public_key = trimspace(run_cmd("sh", "-c", "cat \"$${OCI_SSH_PUBKEY_FILE:-$HOME/.ssh/id_ed25519.pub}\""))
}

inputs = {
  # Account-specific OCID, sourced from the shell so it stays out of git.
  # Root compartment OCID = tenancy OCID is fine. The VCN/subnet/gateway are
  # created by this stack — nothing pre-existing is reused.
  compartment_ocid = get_env("OCI_compartment_ocid")
  # Optional AD override if the default AD is out of A1 capacity.
  availability_domain = get_env("OCI_availability_domain", "")

  # Instance is created by default now (actively pursuing the VM). Set
  # OCI_CREATE_INSTANCE=false to go network-only (defer the VM) without a code
  # edit. Default true so the upgrade-resize path never destroys the instance.
  create_instance = get_env("OCI_CREATE_INSTANCE", "true") == "true"

  display_name   = "voyager"
  ssh_public_key = local.ssh_public_key

  # Shape. voyager actually runs the AMD micro (E2.1.Micro, x86_64) — A1.Flex
  # capacity is scarce in sa-saopaulo-1, so the default matches reality (a
  # stale A1.Flex default made every apply want to reshape the live DR anchor).
  # E2.1.Micro is fixed 1 OCPU/1 GB; the module ignores shape_config for it, so
  # ocpus/memory_in_gbs below are inert unless OCI_SHAPE flips back to A1.Flex
  # (steady-state goal for a future capacity window).
  shape = get_env("OCI_SHAPE", "VM.Standard.E2.1.Micro")

  # Boot from a prebuilt NixOS custom image (imported into OCI) instead of the
  # stock Ubuntu entrypoint. Set OCI_IMAGE_OCID to the imported image's OCID —
  # required for the x86 micro (can't kexec-install). Empty = Ubuntu entrypoint.
  custom_image_ocid = get_env("OCI_IMAGE_OCID", "")

  # Free-tier guard: alert on any real spend. Override via OCI_BUDGET_EMAIL.
  budget_alert_email = get_env("OCI_BUDGET_EMAIL", "erikbogado@gmail.com")

  # NetBird public relay (self-hosted overlay RFC §4/§4a/§6b-H2). vanguard is
  # this shared VCN's public relay (R3a), so its security list now carries the
  # relay posture: 22 closed, 443/tcp+udp world-open, 2222 kept hardened. Applied
  # from a wired LAN host. Env override (OCI_RELAY_PUBLIC_SURFACE=false) still
  # closes it. reserve_public_ip stays human-gated/off: vanguard uses an
  # ephemeral IP pinned in DNS by a static TF record (cloudflare/dns relay2),
  # and voyager's reserved IP is a separate Phase-O decision. telstar
  # (compute-telstar) sets neither, so it stays on the module defaults.
  reserve_public_ip    = get_env("OCI_RESERVE_PUBLIC_IP", "false") == "true"
  relay_public_surface = get_env("OCI_RELAY_PUBLIC_SURFACE", "true") == "true"

  # Always-Free A1 allocation (pool total is 4 OCPU / 24 GB). Starts at 1/6 to
  # land scarce capacity and validate the flow; upgrade later by exporting
  # OCI_OCPUS=2 OCI_MEMORY_GBS=12 and re-applying (see oracle/README.md).
  ocpus          = tonumber(get_env("OCI_OCPUS", "1"))
  memory_in_gbs  = tonumber(get_env("OCI_MEMORY_GBS", "6"))
  boot_volume_gb = 50
}
