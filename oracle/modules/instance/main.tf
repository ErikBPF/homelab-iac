# voyager — offsite backup receiver on an Oracle Always-Free Ampere A1 VM,
# with its whole network created here (clean slate; nothing pre-existing
# reused). Ubuntu image is the install entrypoint; the host is then converted
# to NixOS via `just deploy-voyager` (nixos-anywhere) from desktop-nixos.

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

# Latest Canonical Ubuntu 24.04 image compatible with the chosen shape. The
# shape filter auto-selects the arch: A1.Flex → aarch64, E2.1.Micro → x86_64.
# Both are Always-Free.
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# --- Network ---------------------------------------------------------------
resource "oci_core_vcn" "voyager" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.name}-vcn"
  dns_label      = var.name
}

resource "oci_core_internet_gateway" "voyager" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.voyager.id
  display_name   = "${var.name}-igw"
}

resource "oci_core_route_table" "voyager" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.voyager.id
  display_name   = "${var.name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.voyager.id
  }
}

resource "oci_core_security_list" "voyager" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.voyager.id
  display_name   = "${var.name}-sl"

  # All egress (tailscale, git, nix substituters, restic clients dialing out).
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH 22: the Ubuntu entrypoint + nixos-anywhere path. Closed entirely once
  # this host becomes a NetBird public relay (relay_public_surface = true,
  # NetBird RFC §6b-H2/Q8-b) — a standing public IP is a scan-accreting target
  # and 22 isn't needed post-cutover; 2222 (below) stays as the hardened
  # break-glass path.
  dynamic "ingress_security_rules" {
    for_each = var.relay_public_surface ? [] : [1]
    content {
      protocol = "6" # TCP
      source   = var.ssh_ingress_cidr
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  # 2222: fleet SSH after the NixOS cutover. Kept world-open even under
  # relay_public_surface (Q8-b: DR-entry independence over scan-surface) —
  # sshd is key-only, non-root, fail2ban/crowdsec-hardened (host-side, out of
  # this module's scope).
  ingress_security_rules {
    protocol = "6"
    source   = var.ssh_ingress_cidr
    tcp_options {
      min = 2222
      max = 2222
    }
  }

  # NetBird relay public surface (RFC §5/§6b-H2, TODO(Phase-O): apply only from
  # a wired LAN host; verify billing — reserved IP is free within 1/tenancy).
  # The relay's single port, two protocols: WSS(tcp) + QUIC(udp), world-open by
  # design (a public relay must be reachable by any peer). NB_ENABLE_STUN stays
  # unset (host-side), so no UDP/3478 is ever opened here.
  dynamic "ingress_security_rules" {
    for_each = var.relay_public_surface ? [1] : []
    content {
      protocol = "6" # TCP
      source   = "0.0.0.0/0"
      tcp_options {
        min = 443
        max = 443
      }
    }
  }
  dynamic "ingress_security_rules" {
    for_each = var.relay_public_surface ? [1] : []
    content {
      protocol = "17" # UDP
      source   = "0.0.0.0/0"
      udp_options {
        min = 443
        max = 443
      }
    }
  }

  # Path-MTU discovery so large packets don't black-hole.
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_subnet" "voyager" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.voyager.id
  cidr_block        = var.subnet_cidr
  display_name      = "${var.name}-subnet"
  dns_label         = var.name
  route_table_id    = oci_core_route_table.voyager.id
  security_list_ids = [oci_core_security_list.voyager.id]
}

# --- Instance --------------------------------------------------------------
resource "oci_core_instance" "voyager" {
  count               = var.create_instance ? 1 : 0
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain != "" ? var.availability_domain : data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = var.display_name
  shape               = var.shape

  # Flex shapes (A1.Flex) size via shape_config; fixed shapes (E2.1.Micro) are
  # 1 OCPU / 1 GB and reject shape_config, so only emit it for Flex.
  dynamic "shape_config" {
    for_each = endswith(var.shape, ".Flex") ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }

  source_details {
    source_type = "image"
    # A custom image (prebuilt NixOS disk imported into OCI) boots straight into
    # NixOS — no Ubuntu entrypoint, no in-place install. Empty = stock Ubuntu.
    source_id               = var.custom_image_ocid != "" ? var.custom_image_ocid : data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id = oci_core_subnet.voyager.id
    # An ephemeral public IP and a reserved public IP can't both sit on the
    # same private IP — when reserve_public_ip takes over the address (below),
    # don't also assign the ephemeral one.
    assign_public_ip = var.reserve_public_ip ? false : true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  # nixos-anywhere wipes and reinstalls this boot volume in place; don't let a
  # destroy preserve it.
  preserve_boot_volume = false

  # The disk no longer matches the original Ubuntu image after the NixOS
  # cutover — don't let image churn trigger a rebuild of a live host.
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}

# --- Reserved public IP (NetBird RFC §4/§4a) --------------------------------
# TODO(Phase-O): apply only from a wired LAN host; verify billing (reserved IP
# free within 1/tenancy). Oracle Always-Free includes exactly one reserved
# public IP per tenancy — it survives instance recreate/terminate, unlike the
# ephemeral IP above. Attached to this instance's primary private IP so
# `relay.<zone>`/`relay2.<zone>` (cloudflare/dns) never need updating.
data "oci_core_vnic_attachments" "voyager" {
  count          = var.create_instance && var.reserve_public_ip ? 1 : 0
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.voyager[0].id
}

data "oci_core_private_ips" "voyager" {
  count   = var.create_instance && var.reserve_public_ip ? 1 : 0
  vnic_id = data.oci_core_vnic_attachments.voyager[0].vnic_attachments[0].vnic_id
}

resource "oci_core_public_ip" "voyager" {
  count          = var.create_instance && var.reserve_public_ip ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.name}-reserved-ip"
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.voyager[0].private_ips[0].id
}
