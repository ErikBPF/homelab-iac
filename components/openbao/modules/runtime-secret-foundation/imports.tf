import {
  to = vault_mount.secret
  id = "secret"
}

import {
  to = vault_auth_backend.approle
  id = "approle"
}

import {
  to = vault_policy.home_read
  id = "home-read"
}

import {
  to = vault_policy.iac_writer
  id = "homelab-iac-ha-harness"
}

import {
  to = vault_approle_auth_backend_role.vault_agent
  id = "auth/approle/role/vault-agent"
}

import {
  to = vault_approle_auth_backend_role.iac_writer
  id = "auth/approle/role/homelab-iac-ha-harness"
}
