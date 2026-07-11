variable "instance_id" { type = string }
variable "ssh_public_key" { type = string }

# Interactive serial-console connection — lets us SSH to the instance's serial
# console (ttyS0) to WATCH the boot (GRUB menu, kernel, getty) in real time,
# for when a box comes up off-network and console-history is stale/unreliable.
# Non-destructive; the connection can be torn down with `terragrunt destroy`.
resource "oci_core_instance_console_connection" "c" {
  instance_id = var.instance_id
  public_key  = var.ssh_public_key
}

# The ready-to-run SSH command (ProxyCommand form) for the serial console.
output "serial_connection_string" {
  value = oci_core_instance_console_connection.c.connection_string
}

output "vnc_connection_string" {
  value = oci_core_instance_console_connection.c.vnc_connection_string
}
