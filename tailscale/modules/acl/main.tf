resource "tailscale_acl" "this" {
  acl = var.acl
}

resource "tailscale_device_key" "nanokvm" {
  device_id           = "nu53rVuxF711CNTRL"
  key_expiry_disabled = true
}
