#!/usr/bin/env bats

@test "Grafana reader stays outside unattended drift and apply" {
  python3 - <<'PY'
import json, os, subprocess, tempfile
from pathlib import Path
unit = "components/grafana/environments/home/argus-reader"
with tempfile.TemporaryDirectory() as temporary:
    directory = Path(temporary)
    command = directory / "terragrunt"
    command.write_text("#!/usr/bin/env python3\nimport json, os, sys\n"
                       "open(os.environ['DRIFT_ARGS'], 'w').write(json.dumps(sys.argv[1:]))\n")
    command.chmod(0o700)
    output = directory / "args.json"
    env = dict(os.environ, PATH=f"{directory}:{os.environ['PATH']}", DRIFT_ARGS=str(output))
    subprocess.run(["bash", "bin/drift-check.sh"], env=env, check=True, stdout=subprocess.DEVNULL)
    args = json.loads(output.read_text())
filters = [args[i+1] for i, arg in enumerate(args) if arg == "--filter"]
assert f"!{unit}" in filters, "unapproved Grafana bootstrap must be excluded from drift"
assert unit not in Path("tests/fixtures/drift-monitored-units.txt").read_text().splitlines(), "bootstrap must not auto-apply"
PY
}

@test "Grafana component cannot persist issued tokens" {
  python3 - <<'PY'
from pathlib import Path
import re
root = Path("components/grafana")
text = "\n".join(p.read_text() for p in root.rglob("*.tf"))
resources = re.findall(r'resource\s+"([^"]+)"', text)
assert resources == ["grafana_service_account"], "only account metadata belongs in Terraform"
provider = (root / "root.hcl").read_text()
assert re.search(r'variable "grafana_bootstrap_auth"\s*\{[^}]*sensitive\s*=\s*true[^}]*ephemeral\s*=\s*true', provider), "bootstrap auth must be sensitive and ephemeral"
assert 'insecure_skip_verify = false' in provider, "provider must verify TLS"
PY
}
