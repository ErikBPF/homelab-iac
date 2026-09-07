#!/usr/bin/env bats

@test "drift pin refresh retains the previously monitored unit set" {
  python3 - <<'PY'
import fnmatch
import json
import os
from pathlib import Path
import subprocess
import tempfile

files = subprocess.check_output(["git", "ls-files", "*/terragrunt.hcl"], text=True)
units = {path.rsplit("/", 1)[0] for path in files.splitlines()}
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
assert args[:2] == ["run", "--all"], args
filters = [args[i+1] for i, arg in enumerate(args) if arg == "--filter"]
assert all(pattern.startswith("!") for pattern in filters), filters
exclusions = [pattern[1:] for pattern in filters]
for pattern in exclusions:
    units.difference_update(fnmatch.filter(units, pattern))
expected = set(Path("tests/fixtures/drift-monitored-units.txt").read_text().splitlines())
assert units == expected, {"unexpected": sorted(units-expected), "lost": sorted(expected-units)}
PY
}

@test "drift check exposes the state key to dependency tofu commands" {
  run grep -F 'export TF_VAR_state_passphrase="${TF_VAR_state_passphrase:-${UNIFI_STATE_PASSPHRASE:-}}"' bin/drift-check.sh

  [ "$status" -eq 0 ]
}

@test "drift check executes its pinned working tree without git refresh" {
  run grep -E 'git (pull|fetch|clone)' bin/drift-check.sh

  [ "$status" -eq 1 ]
}

@test "drift check serializes fresh-source initialization" {
  run grep -F -- "--parallelism 1" bin/drift-check.sh

  [ "$status" -eq 0 ]
}

@test "drift check excludes the disposable LiteLLM lifecycle canary" {
  run grep -F -- "--filter '!components/litellm/environments/home/canary'" bin/drift-check.sh

  [ "$status" -eq 0 ]
}

@test "drift alert includes bounded plan evidence for Cleytin" {
  run grep -F -- "grep -am 40 -E 'Plan:|will be (updated|created|destroyed)|# '" bin/drift-check.sh
  [ "$status" -eq 0 ]

  run grep -F -- 'summary="${summary:0:1500}"' bin/drift-check.sh
  [ "$status" -eq 0 ]

  run grep -F -- '--arg summary "$summary"' bin/drift-check.sh
  [ "$status" -eq 0 ]

  run grep -F -- '"\n\n"+$summary' bin/drift-check.sh
  [ "$status" -eq 0 ]
}
