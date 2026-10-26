#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
  STUB="$BATS_TEST_TMPDIR"
  cat > "$STUB/terragrunt" <<'SH'
#!/usr/bin/env bash
case " $* " in
  *" plan "*)
    unit=""; prev=""
    for arg in "$@"; do
      [ "$prev" = "--filter" ] && unit="$arg"
      prev="$arg"
    done
    if [ -n "${DRIFT_UNIT:-}" ] && [ "$unit" != "$DRIFT_UNIT" ]; then
      echo "No changes. Your infrastructure matches the configuration."
      exit 0
    fi
    if [ -e "$APPLY_MARKER" ] && [ "${NEVER_CONVERGE:-0}" != "1" ]; then
      echo "No changes. Your infrastructure matches the configuration."
      exit 0
    fi
    printf '%s\n' "$PLAN_OUT"
    exit "${PLAN_RC:-2}"
    ;;
  *" apply "*)
    touch "$APPLY_MARKER"
    exit "${APPLY_RC:-0}"
    ;;
esac
exit 0
SH
  cat > "$STUB/curl" <<'SH'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
  if [ "$1" = "--data" ]; then shift; printf '%s' "$1" > "$DISCORD_PAYLOAD"; fi
  shift
done
SH
  chmod 700 "$STUB/terragrunt" "$STUB/curl"
  export PLAN_OUT='19:57:07.953 STDOUT [github/repos] tofu:   # github_repository.this["aster"] will be updated in-place
19:57:07.953 STDOUT [github/repos] tofu:       ~ visibility = "public" -> "private"
19:57:07.953 STDOUT [github/repos] tofu: Plan: 0 to add, 2 to change, 0 to destroy.'
}

run_apply() {
  run env PATH="$STUB:$PATH" \
    APPLY_MARKER="$BATS_TEST_TMPDIR/applied" \
    DISCORD_PAYLOAD="$BATS_TEST_TMPDIR/payload.json" \
    DISCORD_WEBHOOK_URL="https://example.invalid/hook" \
    IAC_APPLY_DENYLIST="${IAC_APPLY_DENYLIST-tailscale/acl}" \
    PLAN_OUT="$PLAN_OUT" PLAN_RC="${PLAN_RC:-2}" APPLY_RC="${APPLY_RC:-0}" \
    DRIFT_UNIT="${DRIFT_UNIT:-}" NEVER_CONVERGE="${NEVER_CONVERGE:-0}" \
    bash "$REPO_ROOT/bin/iac-apply.sh"
}

@test "clean plan applies nothing" {
  PLAN_RC=0 run_apply

  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  [ ! -e "$BATS_TEST_TMPDIR/payload.json" ]
}

@test "non-destructive drift is applied and reported" {
  DRIFT_UNIT=github/repos run_apply

  [ "$status" -eq 0 ]
  [ -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'merged-main applied'
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'github/repos'
}

@test "a plan with destroys is refused without applying" {
  DRIFT_UNIT=tailscale/dns PLAN_OUT='19:57:07.953 STDOUT [tailscale/dns] tofu: Plan: 0 to add, 1 to change, 1 to destroy.' run_apply

  [ "$status" -eq 3 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'would destroy resources in: tailscale/dns'
}

@test "denylisted units are never applied automatically" {
  DRIFT_UNIT=tailscale/acl PLAN_OUT='19:57:07.953 STDOUT [tailscale/acl] tofu:   ~ acl = <<-EOT
19:57:07.953 STDOUT [tailscale/acl] tofu: Plan: 0 to add, 1 to change, 0 to destroy.' run_apply

  [ "$status" -eq 3 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'human-only units drifted: tailscale/acl'
}

@test "a failed plan stops without applying" {
  DRIFT_UNIT=github/repos PLAN_RC=1 run_apply

  [ "$status" -eq 1 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'merged-main plan failed'
}

@test "a failed apply reports and does not claim success" {
  DRIFT_UNIT=github/repos APPLY_RC=1 run_apply

  [ "$status" -eq 1 ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'merged-main apply failed'
}

@test "destroy counts ending in zero are still refused" {
  DRIFT_UNIT=github/repos PLAN_OUT='19:57:07.953 STDOUT [github/repos] tofu: Plan: 1 to add, 0 to change, 10 to destroy.' run_apply

  [ "$status" -eq 3 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'would destroy resources in: github/repos'
}

@test "destroy counts are parsed from an import-bearing plan line" {
  DRIFT_UNIT=github/repos PLAN_OUT='19:57:07.953 STDOUT [github/repos] tofu: Plan: 1 to import, 0 to add, 0 to change, 3 to destroy.' run_apply

  [ "$status" -eq 3 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'would destroy resources in: github/repos'
}

@test "an unattributable plan is refused instead of applied blind" {
  DRIFT_UNIT=tailscale/dns PLAN_OUT='19:57:07.953 STDOUT [tailscale/dns] terraform: Plan: 0 to add, 1 to change, 1 to destroy.' run_apply

  [ "$status" -eq 3 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'no unit could be attributed'
}

@test "a changed unit without plan evidence is refused" {
  PLAN_OUT='19:57:07.953 STDOUT [github/repos] tofu: Plan: 0 to add, 2 to change, 0 to destroy.' run_apply

  [ "$status" -eq 3 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'no plan evidence for'
}

@test "drift that does not converge is reported instead of marked applied" {
  DRIFT_UNIT=github/repos NEVER_CONVERGE=1 run_apply

  [ "$status" -eq 1 ]
  [ -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'did not converge'
}

@test "an empty denylist disables the guard" {
  DRIFT_UNIT=tailscale/acl IAC_APPLY_DENYLIST= PLAN_OUT='19:57:07.953 STDOUT [tailscale/acl] tofu:   ~ acl = <<-EOT
19:57:07.953 STDOUT [tailscale/acl] tofu: Plan: 0 to add, 1 to change, 0 to destroy.' run_apply

  [ "$status" -eq 0 ]
  [ -e "$BATS_TEST_TMPDIR/applied" ]
}

@test "the apply scope comes from the drift-check fixture" {
  run grep -F 'tests/fixtures/drift-monitored-units.txt' bin/iac-apply.sh

  [ "$status" -eq 0 ]
}
