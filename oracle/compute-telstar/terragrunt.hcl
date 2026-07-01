# telstar — a second Always-Free Ampere A1 host (2 OCPU / 12 GB, aarch64) for
# exposing personal projects to the public internet. Separate Terragrunt unit
# (own state) reusing the shared instance module; the budget guard is owned by
# the voyager unit (one COMPARTMENT budget per compartment), so create_budget is
# false here. A1 capacity is scarce in sa-saopaulo-1 — `terragrunt apply` may
# fail with "Out of host capacity"; a retry cron drives it until capacity frees.
# After it lands: take public_ip → set hosts.telstar.ip in desktop-nixos
# meta.nix (regenerate fleet.json) → `just deploy-telstar` (nixos-anywhere).

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
  name          = "telstar"
  display_name  = "telstar"
  create_budget = false

  compartment_ocid    = get_env("OCI_compartment_ocid")
  availability_domain = get_env("OCI_availability_domain", "")
  create_instance     = get_env("OCI_CREATE_INSTANCE", "true") == "true"
  ssh_public_key      = local.ssh_public_key
  budget_alert_email  = get_env("OCI_BUDGET_EMAIL", "erikbogado@gmail.com")

  # Ampere A1 (aarch64) is telstar's intended shape — ample RAM, so it installs
  # cleanly via nixos-anywhere (no kexec-OOM / image-import dance the x86 micro
  # needed). Default 2 OCPU / 12 GB (half the 4 OCPU / 24 GB free A1 pool).
  shape          = get_env("OCI_SHAPE", "VM.Standard.A1.Flex")
  ocpus          = tonumber(get_env("OCI_OCPUS", "2"))
  memory_in_gbs  = tonumber(get_env("OCI_MEMORY_GBS", "12"))
  boot_volume_gb = 50

  # No custom image — telstar boots the stock Ubuntu entrypoint, then converts
  # to NixOS via nixos-anywhere (A1 has the RAM the x86 micro lacked).
  custom_image_ocid = get_env("OCI_IMAGE_OCID", "")

  # Distinct network from voyager's 10.0.0.0/16 (separate VCN/state regardless,
  # but keep CIDRs disjoint for sanity).
  vcn_cidr    = "10.1.0.0/16"
  subnet_cidr = "10.1.1.0/24"
}
