#!/usr/bin/env bats

@test "Kepler Wazuh reader has one exact read path and a dedicated bounded AppRole" {
  python3 - <<'PY'
from pathlib import Path
import re
path = Path('components/openbao/modules/runtime-secret-foundation/wazuh-kepler-reader.tf')
assert path.exists(), 'dedicated Kepler Wazuh reader missing'
source = path.read_text()
resources = re.findall(r'resource "([^"]+)" "([^"]+)" \{(.*?)^\}', source, re.M | re.S)
assert [(kind, name) for kind, name, body in resources] == [('vault_policy','wazuh_kepler_reader'), ('vault_approle_auth_backend_role','wazuh_kepler_reader')]
policy, role = [body for kind, name, body in resources]
assert re.findall(r'path "([^"]+)"', policy) == ['secret/data/fleet/wazuh/manager-scale/kepler']
assert re.findall(r'capabilities\s*=\s*\[([^]]+)\]', policy) == ['"read"']
identity = 'svc-desktop-nixos-kepler-wazuh-manager-scale-reader'
assert f'name   = "{identity}"' in policy
assert f'role_name               = "{identity}"' in role
assert 'token_policies          = [vault_policy.wazuh_kepler_reader.name]' in role
for setting, value in [('bind_secret_id','true'), ('token_no_default_policy','true'), ('token_ttl','300'), ('token_max_ttl','300'), ('secret_id_ttl','7776000')]:
    assert re.search(rf'\b{setting}\s*=\s*{value}\b', role), setting
assert 'harbor' not in source.lower()
assert 'secret_id"' not in source and 'vault_kv_secret' not in source
PY
}
