#!/usr/bin/env python3
"""Exercise the actual just/wrapper boundary with synthetic OpenBao transport."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ConfigManager(unittest.TestCase):
    def test_scoped_lookup_revocation_and_no_secret_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            curl = root / "curl"
            curl.write_text("""#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
url=sys.argv[-1]
with open(os.environ['CALLS'], 'a') as f:
    f.write(json.dumps({'path':url.split('/v1/')[-1], 'credentialInArgs': 'A'*48 in ' '.join(sys.argv)})+'\\n')
if url.endswith('/auth/approle/login'):
    data=json.load(sys.stdin)
    assert data == {'role_id':'fixture-role', 'secret_id':'fixture-secret-id'}
    print(json.dumps({'auth':{'client_token':'fixture-vault-token'}}))
elif url.endswith('/auth/token/revoke-self'):
    if os.environ.get('CASE') == 'revoke-failure': sys.exit(22)
elif url.endswith('/secret/data/iac/authentik-config-manager'):
    if os.environ.get('CASE') == 'lookup-failure': sys.exit(22)
    username='wrong-identity' if os.environ.get('CASE') == 'wrong-identity' else 'svc-homelab-iac-authentik-config-manager'
    print(json.dumps({'data':{'data':{'AUTHENTIK_CONFIG_MANAGER_USERNAME':username,'AUTHENTIK_CONFIG_MANAGER_TOKEN':('invalid token' if os.environ.get('CASE') == 'malformed-token' else 'A'*48)}}}))
else:
    sys.exit(99)
""")
            curl.chmod(0o755)
            tg = root / "terragrunt"
            tg.write_text("""#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
assert os.environ['AUTHENTIK_CONFIG_MANAGER_TOKEN'] == 'A'*48
assert os.environ['AWS_ACCESS_KEY_ID'] == 'fixture-state-user'
assert os.environ['AWS_SECRET_ACCESS_KEY'] == 'fixture-state-password'
assert os.environ['TF_VAR_state_passphrase'] == 'fixture-state-key'
assert Path.cwd().as_posix().endswith('/components/authentik/environments/home/openwebui-oidc')
assert sys.argv[1:] == ['plan','-out=fixture.plan']
Path(os.environ['EXECUTED']).write_text('verified')
""")
            tg.chmod(0o755)
            env = {'PATH':str(root)+os.pathsep+os.environ['PATH'], 'HOME':directory,
                   'OPENBAO_AUTHENTIK_CONFIG_MANAGER_READER_ROLE_ID':'fixture-role',
                   'OPENBAO_AUTHENTIK_CONFIG_MANAGER_READER_SECRET_ID':'fixture-secret-id',
                   'VAULT_ADDR':'https://bao.invalid', 'CALLS':str(root/'calls'),
                   'EXECUTED':str(root/'executed'), 'MINIO_TFSTATE_ROOT_USER':'fixture-state-user',
                   'MINIO_TFSTATE_ROOT_PASSWORD':'fixture-state-password', 'UNIFI_STATE_PASSPHRASE':'fixture-state-key'}
            for case in ('success','lookup-failure','wrong-identity','revoke-failure','malformed-token'):
                (root/'calls').unlink(missing_ok=True)
                (root/'executed').unlink(missing_ok=True)
                result = subprocess.run(['just','authentik-config-manager','plan','-out=fixture.plan'],
                                        cwd=ROOT, env={**env,'CASE':case}, capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, case == 'success', 'unexpected wrapper result')
                self.assertEqual((root/'executed').exists(), case == 'success')
                calls=[json.loads(line) for line in (root/'calls').read_text().splitlines()]
                expected=['auth/approle/login','secret/data/iac/authentik-config-manager','auth/token/revoke-self']
                if case == 'revoke-failure': expected.append('auth/token/revoke-self')
                self.assertEqual([call['path'] for call in calls], expected)
                self.assertTrue(all(not call['credentialInArgs'] for call in calls))
                for value in ('A'*48,'fixture-vault-token','fixture-secret-id'):
                    self.assertNotIn(value, result.stdout+result.stderr)


if __name__ == '__main__':
    unittest.main()
