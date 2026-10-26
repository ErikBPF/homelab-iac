#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
  STUB="$BATS_TEST_TMPDIR"
  cat > "$STUB/terragrunt" <<'SH'
#!/usr/bin/env bash
case " $* " in
  *" plan "*)
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
    PLAN_OUT="$PLAN_OUT" PLAN_RC="${PLAN_RC:-2}" APPLY_RC="${APPLY_RC:-0}" \
    bash "$REPO_ROOT/bin/iac-apply.sh"
}

@test "clean plan applies nothing" {
  PLAN_RC=0 run_apply

  [ "$status" -eq 0 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  [ ! -e "$BATS_TEST_TMPDIR/payload.json" ]
}

@test "non-destructive drift is applied and reported" {
  run_apply

  [ "$status" -eq 0 ]
  [ -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'merged-main applied'
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'github/repos'
}

@test "a plan with destroys is refused without applying" {
  PLAN_OUT='19:57:07.953 STDOUT [tailscale/dns] tofu: Plan: 0 to add, 1 to change, 1 to destroy.' run_apply

  [ "$status" -eq 3 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'would destroy resources in: tailscale/dns'
}

@test "denylisted units are never applied automatically" {
  PLAN_OUT='19:57:07.953 STDOUT [tailscale/acl] tofu:   ~ acl = <<-EOT
19:57:07.953 STDOUT [tailscale/acl] tofu: Plan: 0 to add, 1 to change, 0 to destroy.' run_apply

  [ "$status" -eq 3 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'human-only units drifted: tailscale/acl'
}

@test "a failed plan stops without applying" {
  PLAN_RC=1 run_apply

  [ "$status" -eq 1 ]
  [ ! -e "$BATS_TEST_TMPDIR/applied" ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'merged-main plan failed'
}

@test "a failed apply reports and does not claim success" {
  APPLY_RC=1 run_apply

  [ "$status" -eq 1 ]
  jq -r .content "$BATS_TEST_TMPDIR/payload.json" | grep -q 'merged-main apply failed'
}

@test "apply scope matches the drift-check exclusions" {
  drift=$(sed -nE "s/^ *--filter '(![^']+)'.*/\1/p" "$REPO_ROOT/bin/drift-check.sh" | sort)
  apply=$(sed -nE "s/^ *--filter '(![^']+)'.*/\1/p" "$REPO_ROOT/bin/iac-apply.sh" | sort)

  [ -n "$drift" ]
  [ "$drift" = "$apply" ]
}
