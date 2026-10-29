#!/usr/bin/env bash
# Apply the merged homelab-iac tree to the live providers.
#
# Called by the discovery `homelab-iac-main-apply` unit after a merge to main.
# Run from a checkout of the merged commit with the provider credentials loaded
# (the NixOS unit decrypts .env.sops and resolves GITHUB_TOKEN first).
#
# Each monitored unit is planned to a saved plan file, the guards inspect those
# plans, and exactly those saved plans are applied — so what was reviewed is
# what runs, and drift appearing between plan and apply cannot slip through.
#
# Guards, because this mutates live infrastructure without a human in the loop:
#   - a plan containing any destroy is refused,
#   - units in IAC_APPLY_DENYLIST (default: tailscale/acl) are never applied
#     automatically — a wholesale ACL overwrite can cut admin access,
#   - a failed plan or apply stops and alerts; there is no blind retry.
set -uo pipefail
CLEYTIN_USER_ID=1532710143517659356
DENYLIST="${IAC_APPLY_DENYLIST-tailscale/acl}"

cd "$(dirname "$0")/.." || exit 1
export TG_TF_PATH="${TG_TF_PATH:-tofu}"

# Same state-key mapping as bin/drift-check.sh.
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-${MINIO_TFSTATE_ROOT_USER:-}}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-${MINIO_TFSTATE_ROOT_PASSWORD:-}}"
export TF_VAR_state_passphrase="${TF_VAR_state_passphrase:-${UNIFI_STATE_PASSPHRASE:-}}"

# The monitored scope lives in one fixture, asserted against bin/drift-check.sh
# by tests/drift-check-contract.bats.
UNITS_FILE=tests/fixtures/drift-monitored-units.txt
if [ ! -r "$UNITS_FILE" ]; then
  echo "homelab-iac apply: missing $UNITS_FILE" >&2
  exit 1
fi

unit_scope() { # unit_scope <unit> -- <tofu args...>
  local unit=$1
  shift
  terragrunt run --all \
    --parallelism 1 \
    --filter "$unit" \
    --non-interactive "$@"
}

alert() { # alert <message>
  echo "homelab-iac apply: $1"
  if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
    curl -fsS -m 10 -H "Content-Type: application/json" \
      --data "$(jq -nc --arg user "$CLEYTIN_USER_ID" --arg c "$1" \
        '{content:("<@"+$user+">\n"+$c),allowed_mentions:{users:[$user]}}')" \
      "$DISCORD_WEBHOOK_URL" >/dev/null || true
  fi
}

plan_dir=$(mktemp -d "${TMPDIR:-/tmp}/homelab-iac-plan.XXXXXX") || exit 1
trap 'rm -rf "$plan_dir"' EXIT
plan_file() { printf '%s/%s.tfplan' "$plan_dir" "$(printf '%s' "$1" | tr '/' '_')"; }

# Plan, guard, apply — repeated because units can read another unit's
# dependency outputs. With a single plan pass, a dependent (e.g. the OpenBao
# copy of a LiteLLM key) plans against its dependency's pre-apply state and is
# never re-planned. Two applies plus a verifying plan pass is the bound.
applied=""
pass=1
while :; do
  detail=""
  changed=""
  while IFS= read -r unit; do
    [ -n "$unit" ] || continue
    out=$(unit_scope "$unit" -- plan -detailed-exitcode -no-color -out="$(plan_file "$unit")" 2>&1)
    code=$?
    case "$code" in
      0) continue ;;
      2) changed+="$unit " ;;
      *)
        printf '%s\n' "$out" | sed -E 's/\x1b\[[0-9;]*m//g' | tail -20
        alert "🔴 **merged-main plan failed** in $unit (exit $code) — nothing applied."
        exit 1
        ;;
    esac
    # Bind evidence to the invocation that produced it before pooling units.
    if ! unit_detail=$(printf '%s\n' "$out" | sed -E 's/\x1b\[[0-9;]*m//g' \
      | sed -nE 's/^.*STDOUT \[([^]]+)\] tofu: (.*)$/\1\t\2/p' \
      | awk -F'\t' '$2 ~ /^(Plan:|  *(~|\+|-|-\/\+|\+\/-|#) )/ && $2 !~ /^ *# \(/'); then
      alert "🛑 **merged-main apply refused** — failed to parse plan evidence for: $unit. Nothing applied."
      exit 3
    fi
    if ! printf '%s\n' "$unit_detail" | awk -F'\t' -v unit="$unit" '
      NF && $1 != unit { foreign = 1 }
      END { exit foreign }
    '; then
      alert "🛑 **merged-main apply refused** — foreign plan evidence while planning: $unit. Nothing applied."
      exit 3
    fi
    detail+="$unit_detail"$'\n'
  done <"$UNITS_FILE"

  if [ -n "$changed" ]; then
    changed="${changed% }"
  fi

  if [ -z "$changed" ]; then
    if [ "$pass" -eq 1 ]; then
      echo "homelab-iac apply: no changes at $(git rev-parse --short HEAD)"
    else
      alert "🟢 **merged-main applied** ${applied}at $(git rev-parse --short HEAD)"
    fi
    exit 0
  fi

  if [ "$pass" -gt 2 ]; then
    alert "🛑 **merged-main did not converge** after two applies — still changing: $changed. Nothing further applied."
    exit 1
  fi

  # Fail closed: the plan carried changes, so empty evidence means the terragrunt
  # log shape changed and both guards would pass on nothing.
  if [ -z "${detail//[[:space:]]/}" ]; then
    alert "🛑 **merged-main apply refused** — plan reported changes but no unit could be attributed. Nothing applied."
    exit 3
  fi

  # Fail closed per unit: the guards below only see $detail, so a changed unit
  # with no attributable evidence would be applied unchecked (including a
  # denylisted or destructive one). Refuse before any guard runs.
  missing=""
  for unit in $changed; do
    if ! printf '%s\n' "$detail" | cut -f1 | grep -qxF "$unit"; then
      missing+="$unit "
    fi
  done
  if [ -n "$missing" ]; then
    alert "🛑 **merged-main apply refused** — no plan evidence for: $missing. Nothing applied."
    exit 3
  fi

  # Resource lines establish attribution, but cannot prove zero destruction.
  # Require one complete summary per changed unit; unknown or repeated output
  # must stop rather than bypass the destroy guard below.
  invalid=""
  for unit in $changed; do
    if ! printf '%s\n' "$detail" | awk -F'\t' -v unit="$unit" '
      $1 == unit && $2 ~ /^Plan:/ {
        count++
        if (NF != 2 || $2 !~ /^Plan: ([0-9]+ to import, )?[0-9]+ to add, [0-9]+ to change, [0-9]+ to destroy\.$/) invalid = 1
      }
      END { exit(count != 1 || invalid) }
    '; then
      invalid+="$unit "
    fi
  done
  if [ -n "$invalid" ]; then
    alert "🛑 **merged-main apply refused** — missing, ambiguous or unsupported plan summary for: $invalid. Nothing applied."
    exit 3
  fi

  # Read the destroy count from the summary line wherever it sits: an
  # import-bearing plan prints "Plan: 1 to import, 0 to add, 0 to change, 3 to
  # destroy." and positional fields would read the wrong number. Explicit
  # destroy/replacement actions also refuse a contradictory zero summary.
  if ! destroys=$(printf '%s\n' "$detail" \
    | awk -F'\t' '
      $2 ~ /^ *(-|-\/\+|\+\/-) resource / ||
      $2 ~ /^ *# .* (will be destroyed|must be replaced)([ (]|$)/ { print $1; next }
      $2 ~ /^Plan: / {
        if (match($2, /[0-9]+ to destroy/)) {
          n = substr($2, RSTART, RLENGTH)
          sub(/ to destroy/, "", n)
          if (n + 0 > 0) print $1
        }
      }' | paste -sd ' ' -); then
    alert "🛑 **merged-main apply refused** — failed to parse destruction evidence. Nothing applied."
    exit 3
  fi
  if [ -n "$destroys" ]; then
    alert "🛑 **merged-main apply refused** — plan would destroy resources in: $destroys. Nothing applied."
    exit 3
  fi

  denied=""
  for unit in $DENYLIST; do
    if printf '%s\n' "$detail" | cut -f1 | grep -qxF "$unit"; then
      denied+="$unit "
    fi
  done
  if [ -n "$denied" ]; then
    alert "🛑 **merged-main apply refused** — human-only units drifted: $denied. Apply those by hand."
    exit 3
  fi

  for unit in $changed; do
    out=$(unit_scope "$unit" -- apply -no-color "$(plan_file "$unit")" 2>&1)
    code=$?
    if [ "$code" -ne 0 ]; then
      printf '%s\n' "$out" | sed -E 's/\x1b\[[0-9;]*m//g' | tail -20
      alert "🔴 **merged-main apply failed** in $unit (exit $code). Retry is manual."
      exit 1
    fi
  done

  applied+="$changed "
  pass=$((pass + 1))
done
