variable "instance_id" { type = string }

# Capture the serial-console history (boot log) — non-interactive, read-only
# diagnostic for why vanguard boots off-network on nixpkgs 26.11.
resource "oci_core_console_history" "h" {
  instance_id = var.instance_id
}

data "oci_core_console_history_data" "c" {
  console_history_id = oci_core_console_history.h.id
  length             = 1048576
}

output "log" {
  value = data.oci_core_console_history_data.c.data
}
