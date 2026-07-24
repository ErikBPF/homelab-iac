resource "vault_kv_secret_v2" "this" {
  mount                = var.mount
  name                 = var.name
  data_json_wo         = jsonencode(var.data)
  data_json_wo_version = var.version
}
