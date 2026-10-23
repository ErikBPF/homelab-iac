resource "tailscale_acl" "this" {
  acl = var.acl
}

resource "tailscale_device_key" "nanokvm" {
  device_id           = "nu53rVuxF711CNTRL"
  key_expiry_disabled = true
}

locals {
  discovery_node_id = "nBNPLvBqRK11CNTRL"
}

data "tailscale_devices" "discovery" {
  filter {
    name   = "hostname"
    values = ["discovery"]
  }
}

# Approve only Discovery's advertised host routes, not every tag:server device.
resource "tailscale_device_subnet_routes" "discovery" {
  device_id = local.discovery_node_id
  routes = [
    "192.168.10.1/32",
    "192.168.10.2/32",
    "192.168.10.4/32",
    "192.168.10.210/32",
  ]

  lifecycle {
    precondition {
      condition = length(data.tailscale_devices.discovery.devices) == 1 && alltrue([
        for device in data.tailscale_devices.discovery.devices :
        device.node_id == local.discovery_node_id &&
        device.authorized &&
        contains(device.tags, "tag:server") &&
        contains(device.addresses, "100.103.52.100")
      ])
      error_message = "Discovery must uniquely match its pinned node ID, be authorized, retain tag:server and TailIP 100.103.52.100. Re-enrollment requires explicit identity review before updating the pin."
    }
  }
}
