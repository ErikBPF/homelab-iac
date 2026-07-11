# vanguard — a second Always-Free AMD micro (VM.Standard.E2.1.Micro, 1 OCPU /
# 1 GB, x86_64), sibling of voyager, standing up as a multi-role offsite node
# (desktop-nixos docs/proposals/2026-07-10-vanguard-second-oracle-node.md).
# Separate Terragrunt unit (own state) reusing the shared instance module; the
# budget guard is owned by the voyager unit (one COMPARTMENT budget per
# compartment), so create_budget is false here, same as telstar. Unlike
# telstar's A1 (scarce capacity), the AMD micro shape is reliably
# provisionable now — same shape/path as voyager, not a capacity-retry target.
#
# Shared-VCN model (Always-Free caps a region at 2 VCNs): vanguard does NOT
# create its own VCN. It carves a subnet inside voyager's existing VCN
# (oracle/compute), reusing voyager's route table + security list. OCIDs
# below are hardcoded from `terragrunt state show` on oracle/compute, per this
# repo's no-dependency-blocks convention.
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

  # Shared VCN: voyager's (oracle/compute), not a new one. vanguard's slice is
  # 10.0.2.0/24, disjoint from voyager's own subnet (10.0.1.0/24) and
  # telstar's (10.0.3.0/24).
  subnet_cidr               = "10.0.2.0/24"
  existing_vcn_id           = "ocid1.vcn.oc1.sa-saopaulo-1.amaaaaaaxbqhvsiab5gfcbv3u7jya2jytackfyqowla4ctze5qhy5y4mnzua"
  existing_route_table_id   = "ocid1.routetable.oc1.sa-saopaulo-1.aaaaaaaamdmjdvjgjge5gdhdxpwyavjs7hsn5zizgcpugnpkpijpbtoukw3a"
  existing_security_list_id = "ocid1.securitylist.oc1.sa-saopaulo-1.aaaaaaaauivzi747bnsixxa7sbciilyq35mrafbvokwvvr5nvv6ygr53prna"
}
