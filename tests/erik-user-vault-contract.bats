#!/usr/bin/env bats

@test "Erik user readers are host-scoped, read-only, and exclude home and SSH paths" {
  python3 - <<'PY'
from pathlib import Path
import re
path = Path('components/openbao/modules/runtime-secret-foundation/main.tf')
source = path.read_text()
policy = re.search(r'resource "vault_policy" "erik_user" \{(.*?)^\}', source, re.M | re.S).group(1)
role = re.search(r'resource "vault_approle_auth_backend_role" "erik_user" \{(.*?)^\}', source, re.M | re.S).group(1)
assert 'erik_user_hosts         = toset(["endeavour", "kepler"])' in source
assert 'for_each = local.erik_user_hosts' in policy
assert 'for_each       = local.erik_user_hosts' in role
assert re.findall(r'path "([^"]+)"', policy) == [
    'secret/data/users/erik/*',
    'secret/metadata/users/erik/*',
    'secret/data/iac/github',
]
assert re.findall(r'capabilities\s*=\s*\[([^]]+)\]', policy) == ['"read"', '"read", "list"', '"read"']
assert not re.search(r'create|update|delete|home/|ssh|fleet/harbor', policy)
assert 'name     = "svc-desktop-nixos-${each.key}-erik-reader"' in policy
assert 'role_name      = "svc-desktop-nixos-${each.key}-erik-reader"' in role
assert 'token_policies = [vault_policy.erik_user[each.key].name]' in role
for setting, value in [('bind_secret_id', 'true'), ('token_ttl', '600'), ('token_max_ttl', '3600'), ('secret_id_ttl', '2592000')]:
    assert re.search(rf'\b{setting}\s*=\s*{value}\b', role), setting
PY
}
