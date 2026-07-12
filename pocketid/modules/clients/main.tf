resource "pocketid_client" "this" {
  for_each = var.clients

  name                 = coalesce(each.value.name, each.key)
  client_id            = each.value.client_id
  is_public            = each.value.is_public
  pkce_enabled         = each.value.pkce_enabled
  callback_urls        = each.value.callback_urls
  logout_callback_urls = each.value.logout_callback_urls
  allowed_user_groups  = each.value.allowed_user_groups
  launch_url           = each.value.launch_url
}
