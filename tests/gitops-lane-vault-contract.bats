#!/usr/bin/env bats

@test "GitOps lanes receive separate read-only Vault AppRoles" {
  run python3 - "$BATS_TEST_DIRNAME/../components/openbao/modules/runtime-secret-foundation/main.tf" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
for lane, path in (
    ("platform", "platform/*"),
    ("homelab", "lab/*"),
    ("home-services", "home-services/*"),
):
    assert re.search(rf'{re.escape(lane)}\s*=\s*"{re.escape(path)}"', text)
assert 'resource "vault_policy" "gitops_lane"' in text
assert 'resource "vault_approle_auth_backend_role" "gitops_lane"' in text
assert 'role_name      = "eso-${each.key}"' in text
assert 'capabilities = ["read"]' in text
assert 'token_ttl      = 1200' in text
assert 'token_max_ttl  = 3600' in text
assert 'resource "vault_approle_auth_backend_role" "eso"' in text
PY
  [ "$status" -eq 0 ]
}

@test "Wazuh host agents receive a dedicated read-only AppRole" {
  run python3 - "$BATS_TEST_DIRNAME/../components/openbao/modules/runtime-secret-foundation/main.tf" <<'PY'
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
policy = text.split('resource "vault_policy" "wazuh_agent"', 1)[1].split("\n}", 1)[0]
role = text.split('resource "vault_approle_auth_backend_role" "wazuh_agent"', 1)[1].split("\n}", 1)[0]

assert 'path "secret/data/platform/wazuh/wazuh-authd-pass"' in policy
assert 'capabilities = ["read"]' in policy
assert 'platform/*' not in policy
assert 'role_name      = "wazuh-agent"' in role
assert 'token_policies = [vault_policy.wazuh_agent.name]' in role
assert 'token_ttl      = 3600' in role
assert 'token_max_ttl  = 14400' in role
PY
  [ "$status" -eq 0 ]
}
