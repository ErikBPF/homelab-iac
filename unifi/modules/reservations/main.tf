resource "unifi_user" "this" {
  for_each = var.reservations

  mac        = each.key
  name       = each.value.name
  fixed_ip   = each.value.fixed_ip
  network_id = each.value.network_id
  note       = each.value.note

  # Provider-internal flags absent from imported state; ignoring them keeps the
  # plan clean without a no-op apply against the controller.
  lifecycle {
    ignore_changes = [allow_existing, skip_forget_on_destroy]
  }
}
