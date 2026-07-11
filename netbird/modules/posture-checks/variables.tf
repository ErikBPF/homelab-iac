variable "posture_checks" {
  description = "NetBird posture checks, keyed by name. Attach to policies via source_posture_checks (RFC §6 — require a minimum client/OS version before a peer is trusted)."
  type = map(object({
    description = optional(string, "")
    netbird_version_check = optional(object({
      min_version = string
    }))
    os_version_check = optional(object({
      linux_min_kernel_version   = optional(string)
      darwin_min_version         = optional(string)
      windows_min_kernel_version = optional(string)
      android_min_version        = optional(string)
      ios_min_version            = optional(string)
    }))
  }))
  default = {}
}
