resource "netbird_posture_check" "this" {
  for_each = var.posture_checks

  name        = each.key
  description = each.value.description

  dynamic "netbird_version_check" {
    for_each = each.value.netbird_version_check[*]
    content {
      min_version = netbird_version_check.value.min_version
    }
  }

  dynamic "os_version_check" {
    for_each = each.value.os_version_check[*]
    content {
      linux_min_kernel_version   = os_version_check.value.linux_min_kernel_version
      darwin_min_version         = os_version_check.value.darwin_min_version
      windows_min_kernel_version = os_version_check.value.windows_min_kernel_version
      android_min_version        = os_version_check.value.android_min_version
      ios_min_version            = os_version_check.value.ios_min_version
    }
  }
}
