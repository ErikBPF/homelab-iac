# NOTE: the provider-cred variables (oci_tenancy_ocid, oci_user_ocid,
# oci_fingerprint, oci_private_key_b64, oci_region) are declared in the
# Terragrunt-generated provider_gen.tf — don't re-declare them here (would be a
# duplicate). main.tf may still reference var.oci_tenancy_ocid.

variable "compartment_ocid" {
  type        = string
  description = "Compartment to create everything in (root compartment OCID = tenancy OCID is fine)."
}

variable "availability_domain" {
  type        = string
  default     = ""
  description = "AD name. Empty = first AD in the tenancy. A1 capacity varies per AD; override if 'Out of host capacity'."
}

variable "name" {
  type        = string
  default     = "voyager"
  description = "Resource name prefix for this host's network/budget objects (vcn/igw/rt/sl/subnet/budget). One module instance per host (separate Terragrunt unit + state); defaults to voyager so the original unit is unchanged."
}

variable "create_budget" {
  type        = bool
  default     = true
  description = "Create the COMPARTMENT-target free-tier budget guard. Unique per compartment, so only one host's unit owns it (voyager); secondary units set false and share it."
}

variable "display_name" {
  type    = string
  default = "voyager"
}

variable "shape" {
  type        = string
  default     = "VM.Standard.A1.Flex"
  description = "Instance shape. A1.Flex = Always-Free Ampere/aarch64 (sized via ocpus/memory_in_gbs). E2.1.Micro = Always-Free AMD/x86_64 (fixed 1 OCPU/1 GB; shape_config ignored). A1 capacity is scarce in sa-saopaulo-1 — set OCI_SHAPE=VM.Standard.E2.1.Micro to land x86 free capacity instead."
  validation {
    condition     = contains(["VM.Standard.A1.Flex", "VM.Standard.E2.1.Micro"], var.shape)
    error_message = "Only the two Always-Free shapes are allowed: VM.Standard.A1.Flex or VM.Standard.E2.1.Micro."
  }
}

variable "custom_image_ocid" {
  type        = string
  default     = ""
  description = "OCID of a custom image to boot from (a prebuilt NixOS disk imported into OCI). Empty = the stock Ubuntu entrypoint image. Set via OCI_IMAGE_OCID to bring the host up directly as NixOS — required for the 1 GB x86 micro, which can't kexec-install and won't cleanly nixos-infect."
}

variable "create_instance" {
  type        = bool
  default     = true
  description = "Toggle the A1 instance. false = manage only the network (VCN/subnet/gateway/SL), defer the VM (e.g. while waiting on A1 capacity / a PAYG decision)."
}

variable "ssh_public_key" {
  type        = string
  description = "Public key injected for the default 'ubuntu' user (used by nixos-anywhere before the NixOS cutover)."
}

# --- Budget guard (PAYG safety net) ----------------------------------------
variable "budget_amount" {
  type        = number
  default     = 1
  description = "Monthly budget cap in USD. Tiny on purpose — everything should stay free-tier ($0)."
}

variable "budget_alert_threshold" {
  type        = number
  default     = 1
  description = "Alert when ACTUAL spend crosses this percent of budget_amount (1% of $1 = $0.01 → fires on any real charge)."
}

variable "budget_alert_email" {
  type        = string
  description = "Email to notify when the budget alert fires."
}

# --- Network (all created by this project — clean slate) -------------------
variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "ssh_ingress_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "Source allowed to reach SSH (22 + 2222). sshd is key-only; tighten to your egress IP if desired."
}

# --- Always-Free guard rails ----------------------------------------------
# The Always-Free Ampere A1 pool is 4 OCPU / 24 GB RAM total and 200 GB block
# storage. These validations make a plan that would leave the free tier FAIL
# instead of silently billing.
variable "ocpus" {
  type    = number
  default = 2
  validation {
    condition     = var.ocpus >= 1 && var.ocpus <= 4
    error_message = "Always-Free A1 pool is 4 OCPU total; keep ocpus in 1..4."
  }
}

variable "memory_in_gbs" {
  type    = number
  default = 12
  validation {
    condition     = var.memory_in_gbs >= 1 && var.memory_in_gbs <= 24
    error_message = "Always-Free A1 pool is 24 GB total; keep memory_in_gbs in 1..24."
  }
}

variable "boot_volume_gb" {
  type    = number
  default = 50
  validation {
    condition     = var.boot_volume_gb >= 50 && var.boot_volume_gb <= 200
    error_message = "A1 boot volume min is 50 GB; Always-Free block storage total is 200 GB."
  }
}
