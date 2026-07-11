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

  # Shape. Default A1.Flex (Ampere/aarch64) is the steady-state goal, but its
  # capacity is scarce in sa-saopaulo-1. Set OCI_SHAPE=VM.Standard.E2.1.Micro
  # to land an x86 free instance now; flip back to A1 when capacity frees.
  shape = get_env("OCI_SHAPE", "VM.Standard.A1.Flex")

  # Boot from a prebuilt NixOS custom image (imported into OCI) instead of the
  # stock Ubuntu entrypoint. Set OCI_IMAGE_OCID to the imported image's OCID —
  # required for the x86 micro (can't kexec-install). Empty = Ubuntu entrypoint.
  custom_image_ocid = get_env("OCI_IMAGE_OCID", "")

  # Free-tier guard: alert on any real spend. Override via OCI_BUDGET_EMAIL.
  budget_alert_email = get_env("OCI_BUDGET_EMAIL", "erikbogado@gmail.com")

  # NetBird public relay (self-hosted overlay RFC §4/§4a/§6b-H2). Written but
  # NOT applied — this is a live-network + billing change, human-gated
  # (Phase O). TODO(Phase-O): apply only from a wired LAN host; verify billing
  # (reserved IP is free within 1/tenancy) before running `terragrunt apply`.
  # telstar (compute-telstar/terragrunt.hcl) does not set these, so it stays on
  # the module's defaults (ephemeral IP, original 22+2222+ICMP SL) — unaffected.
  reserve_public_ip    = get_env("OCI_RESERVE_PUBLIC_IP", "false") == "true"
  relay_public_surface = get_env("OCI_RELAY_PUBLIC_SURFACE", "false") == "true"

  # Always-Free A1 allocation (pool total is 4 OCPU / 24 GB). Starts at 1/6 to
  # land scarce capacity and validate the flow; upgrade later by exporting
  # OCI_OCPUS=2 OCI_MEMORY_GBS=12 and re-applying (see oracle/README.md).
  ocpus          = tonumber(get_env("OCI_OCPUS", "1"))
  memory_in_gbs  = tonumber(get_env("OCI_MEMORY_GBS", "6"))
  boot_volume_gb = 50
}
