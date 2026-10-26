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

@test "drift alert keeps the changed attribute lines and names the units" {
  cat > "$BATS_TEST_TMPDIR/terragrunt" <<'SH'
#!/usr/bin/env bash
printf '%s\n' \
  '19:57:07.953 STDOUT [tailscale/dns] tofu: No changes. Your infrastructure matches the configuration.' \
  '19:57:07.953 STDOUT [github/repos] tofu:   # github_repository.this["aster"] will be updated in-place' \
  '19:57:07.953 STDOUT [github/repos] tofu:       ~ visibility = "public" -> "private"' \
  '19:57:07.953 STDOUT [github/repos] tofu:         # (34 unchanged attributes hidden)' \
  '19:57:07.953 STDOUT [github/repos] tofu: Plan: 0 to add, 2 to change, 0 to destroy.'
exit 2
SH
  chmod 700 "$BATS_TEST_TMPDIR/terragrunt"

  run env PATH="$BATS_TEST_TMPDIR:$PATH" bash bin/drift-check.sh

  [ "$status" -eq 2 ]
  [[ "$output" == *"DRIFT DETECTED in: github/repos"* ]]
  [[ "$output" == *'~ visibility = "public" -> "private"'* ]]
  [[ "$output" != *"unchanged attributes hidden"* ]]
  [[ "$output" != *"tailscale/dns"* ]]
  [[ "$output" != *"No changes"* ]]
}

@test "drift alert survives clean units ahead of a late drifting unit" {
  cat > "$BATS_TEST_TMPDIR/terragrunt" <<'SH'
#!/usr/bin/env bash
for unit in adguard/config adguard/filtering cloudflare/access cloudflare/dns cloudflare/tunnel; do
  printf '%s\n' "19:57:07.953 STDOUT [$unit] tofu: No changes. Your infrastructure matches the configuration."
done
for attr in one two three four five six seven eight; do
  printf '%s\n' "19:57:07.953 STDOUT [unifi/environments/home/wlan] tofu:       ~ $attr = \"a\" -> \"b\""
done
printf '%s\n' '19:57:07.953 STDOUT [unifi/environments/home/wlan] tofu: Plan: 0 to add, 8 to change, 0 to destroy.'
exit 2
SH
  chmod 700 "$BATS_TEST_TMPDIR/terragrunt"

  run env PATH="$BATS_TEST_TMPDIR:$PATH" bash bin/drift-check.sh

  [ "$status" -eq 2 ]
  [[ "$output" == *"DRIFT DETECTED in: unifi/environments/home/wlan"* ]]
  [[ "$output" == *'eight = "a" -> "b"'* ]]
  [[ "$output" == *"Plan: 0 to add, 8 to change, 0 to destroy."* ]]
}

@test "drift alert payload stays inside Discord's content limit for the full scope" {
  cat > "$BATS_TEST_TMPDIR/terragrunt" <<'SH'
#!/usr/bin/env bash
fixture="tests/fixtures/drift-monitored-units.txt"
while read -r unit; do
  printf '%s\n' "19:57:07.953 STDOUT [$unit] tofu:   # resource.this[\"x\"] will be updated in-place"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    printf '%s\n' "19:57:07.953 STDOUT [$unit] tofu:       ~ attribute_$i = \"aaaaaaaaaa\" -> \"bbbbbbbbbb\""
  done
  printf '%s\n' "19:57:07.953 STDOUT [$unit] tofu: Plan: 0 to add, 10 to change, 0 to destroy."
done < "$fixture"
exit 2
SH
  cat > "$BATS_TEST_TMPDIR/curl" <<'SH'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
  if [ "$1" = "--data" ]; then shift; printf '%s' "$1" > "$DISCORD_PAYLOAD"; fi
  shift
done
SH
  chmod 700 "$BATS_TEST_TMPDIR/terragrunt" "$BATS_TEST_TMPDIR/curl"

  disc_payload="$BATS_TEST_TMPDIR/payload.json"
  run env PATH="$BATS_TEST_TMPDIR:$PATH" DISCORD_PAYLOAD="$disc_payload" \
    DISCORD_WEBHOOK_URL="https://example.invalid/webhook" bash bin/drift-check.sh

  [ "$status" -eq 2 ]
  content_bytes=$(jq -r .content "$disc_payload" | wc -c)
  [ "$content_bytes" -lt 2000 ]
  jq -r .content "$disc_payload" | grep -q 'homelab-iac drift'
  jq -r .content "$disc_payload" | grep -q '\[adguard/config\]'
}
