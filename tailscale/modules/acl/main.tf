resource "tailscale_acl" "this" {
  acl = var.acl
}

resource "tailscale_device_key" "nanokvm" {
  device_id           = "nu53rVuxF711CNTRL"
  key_expiry_disabled = true
}

# Approve only Discovery's advertised host routes, not every tag:server device.
resource "tailscale_device_subnet_routes" "discovery" {
  device_id = "nBNPLvBqRK11CNTRL"
  routes = [
    "192.168.10.1/32",
    "192.168.10.2/32",
    "192.168.10.4/32",
    "192.168.10.210/32",
  ]
}
