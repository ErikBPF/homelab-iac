# vanguard — a second Always-Free AMD micro (VM.Standard.E2.1.Micro, 1 OCPU /
# 1 GB, x86_64), sibling of voyager, standing up as a multi-role offsite node
# (desktop-nixos docs/proposals/2026-07-10-vanguard-second-oracle-node.md).
# Separate Terragrunt unit (own state) reusing the shared instance module; the
# budget guard is owned by the voyager unit (one COMPARTMENT budget per
# compartment), so create_budget is false here, same as telstar. Unlike
# telstar's A1 (scarce capacity), the AMD micro shape is reliably
# provisionable now — same shape/path as voyager, not a capacity-retry target.
# After it lands: take public_ip → set fleet.hosts.vanguard.ip in desktop-nixos
# meta.nix (regenerate fleet.json) → `just deploy vanguard <ip> 2222`
# (nixos-infect path, per voyager).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_terragrunt_dir()}/../modules/instance"
}

locals {
  ssh_public_key = trimspace(run_cmd("sh", "-c", "cat \"$${OCI_SSH_PUBKEY_FILE:-$HOME/.ssh/id_ed25519.pub}\""))
}

inputs = {
  name          = "vanguard"
  display_name  = "vanguard"
  create_budget = false

  compartment_ocid    = get_env("OCI_compartment_ocid")
  availability_domain = get_env("OCI_availability_domain", "")
  create_instance     = get_env("OCI_CREATE_INSTANCE", "true") == "true"
  ssh_public_key      = local.ssh_public_key
  budget_alert_email  = get_env("OCI_BUDGET_EMAIL", "erikbogado@gmail.com")

  # AMD micro (x86_64) — fixed 1 OCPU/1 GB, shape_config is ignored by the
  # module for non-Flex shapes, so ocpus/memory_in_gbs are left at their
  # (unused) defaults. No custom image — vanguard boots the stock Ubuntu
  # entrypoint, then converts to NixOS via nixos-infect (same path as
  # voyager; the 1 GB micro can't kexec-install).
  shape             = get_env("OCI_SHAPE", "VM.Standard.E2.1.Micro")
  boot_volume_gb    = 50
  custom_image_ocid = get_env("OCI_IMAGE_OCID", "")

  # Own VCN, disjoint from voyager's 10.0.0.0/16 and telstar's 10.1.0.0/16.
  vcn_cidr    = "10.2.0.0/16"
  subnet_cidr = "10.2.1.0/24"
}
