resource "netbird_group" "this" {
  for_each = var.groups

  name      = each.key
  peers     = each.value.peers
  resources = each.value.resources

  # Setup-key and SSO enrollment own dynamic group membership. Terraform owns
  # the group object; reconciling an empty seed list would evict live peers.
  lifecycle {
    ignore_changes = [peers]
  }
}
