#!/usr/bin/env bash
# Drift detection for the adopted homelab-iac units: plan each selected unit and
# report if live infra has drifted from code. Exit 0 = clean, 2 = drift, 1 = err.
#
# Run from a host with LAN/tailnet reach to the providers (UDM, AdGuard, …) and
# the creds loaded (devenv loads .env; or sops-decrypt .env.sops first).
# Optional: set DISCORD_WEBHOOK_URL to a Discord webhook to get alerted on drift.
set -uo pipefail
CLEYTIN_USER_ID=1532710143517659356

cd "$(dirname "$0")/.." || exit 1

# An untrappable interruption must not retain an earlier successful plan.
# Callers must also clear before invoking us, since execution itself can fail.
if [ -n "${DRIFT_RESULT_FILE:-}" ]; then
  rm -f -- "$DRIFT_RESULT_FILE" || exit 1
fi

export TG_TF_PATH="${TG_TF_PATH:-tofu}"

# Optional private machine result: detection is independent of webhook delivery.
# This record deliberately excludes provider output and credential values.
outcome=error
notification=not-configured
[ -z "${DISCORD_WEBHOOK_URL:-}" ] || notification=unknown
write_result() {
  [ -n "${DRIFT_RESULT_FILE:-}" ] || return 0
  local revision scope temporary
  revision="${DRIFT_SOURCE_REVISION:-$(git rev-parse HEAD 2>/dev/null || printf unknown)}"
  [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || revision=unknown
  scope=$(sha256sum tests/fixtures/drift-monitored-units.txt) || return 0
  scope=${scope%% *}
  temporary=$(umask 077; mktemp "${DRIFT_RESULT_FILE}.XXXXXX") || return 0
  if jq -nc --arg outcome "$outcome" --arg notification "$notification" \
    --arg revision "$revision" --arg scope "$scope" \
    '{schemaVersion:1,outcome:$outcome,notification:$notification,sourceRevision:$revision,scopeSha256:$scope}' > "$temporary" \
    && mv -f "$temporary" "$DRIFT_RESULT_FILE"; then
    return 0
  fi
  rm -f "$temporary"
  echo "homelab-iac: structured result publication failed" >&2
}
trap write_result EXIT

# State lives in MinIO (S3 backend). The bucket creds are MINIO_TFSTATE_* in the
# secret store; OpenTofu's s3 backend reads AWS_*. Map them if not already set.
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-${MINIO_TFSTATE_ROOT_USER:-}}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-${MINIO_TFSTATE_ROOT_PASSWORD:-}}"
export TF_VAR_state_passphrase="${TF_VAR_state_passphrase:-${UNIFI_STATE_PASSPHRASE:-}}"

# Telstar's capture loop owns this state while it retries OCI capacity. Planning
# it concurrently races the remote state lock; its service provides the health
# signal instead.
# The remaining exclusions retain Discovery's 24-unit monitoring scope while
# refreshing the paused-HA catalog. Adopt new units only after their runtime
# credentials and zero-diff plans pass; see docs/2026-09-07-paused-ha-route.md.
# cloudflare/access is bootstrap-only: it needs a token with Access: Apps and
# Policies plus Service Tokens edit, which the shared CLOUDFLARE_API_TOKEN does
# not hold. Keep it out of the unattended scope until that token exists; see
# the BOOTSTRAP block in cloudflare/access/terragrunt.hcl.
# The two voice credential units (voice-key, voice-litellm) were applied
# interactively; their unattended credential and zero-diff qualification is
# still pending, so only those two are filtered below. The voice model manifest
# in components/litellm/environments/home/production stays in the adopted scope
# and is therefore planned and applied by the merged-main runner.
out=$(terragrunt run --all \
  --parallelism 1 \
  --filter '!oracle/compute-telstar' \
  --filter '!components/litellm/environments/home/canary' \
  --filter '!components/litellm/environments/home/voice-key' \
  --filter '!components/openbao/environments/home/voice-litellm' \
  --filter '!components/authentik/environments/home/aster-identity-reader' \
  --filter '!components/authentik/environments/home/iac-access' \
  --filter '!components/grafana/environments/home/argus-reader' \
  --filter '!components/authentik/environments/home/openwebui-oidc' \
  --filter '!components/harbor-iam/environments/home/fleet-readers' \
  --filter '!components/harbor-iam/environments/home/production' \
  --filter '!components/harbor-iam/environments/home/project-members' \
  --filter '!components/litellm/environments/home/deepseek-harness-key' \
  --filter '!components/litellm/environments/home/ocr-review-key' \
  --filter '!components/openbao/environments/home/aster-authentik-reader' \
  --filter '!components/openbao/environments/home/authentik-runtime' \
  --filter '!components/openbao/environments/home/authentik-config-manager' \
  --filter '!components/openbao/environments/home/deepseek-harness-litellm' \
  --filter '!components/openbao/environments/home/ocr-review-litellm' \
  --filter '!components/openbao/environments/home/harbor-project-iam' \
  --filter '!components/openbao/environments/home/runtime-secret-foundation' \
  --filter '!cloudflare/access' \
  --non-interactive -- plan -detailed-exitcode -no-color 2>&1)
code=$?

case "$code" in
  0)
    outcome=clean
    notification=not-required
    echo "homelab-iac: no drift in the adopted unit scope."
    ;;
  2)
    outcome=drift
    # Attribute terragrunt's per-unit lines to their unit, then keep only the
    # evidence: changed attributes and the per-unit Plan line. Clean units
    # ("No changes") are dropped so they neither pad the alert nor its budget.
    detail=$(printf '%s\n' "$out" | sed -E 's/\x1b\[[0-9;]*m//g' \
      | sed -nE 's/^.*STDOUT \[([^]]+)\] tofu: (.*)$/\1\t\2/p' \
      | awk -F'\t' '$2 ~ /^(Plan:|  *(~|\+|-|#) )/ && $2 !~ /^ *# \(/ { print "[" $1 "] " $2 }' || true)
    # Only units that produced diff lines: a clean unit cannot name itself in
    # the header, and an unbounded list blows Discord's 2000-char content cap.
    units=$(printf '%s\n' "$detail" | sed -nE 's/^\[([^]]+)\] .*/\1/p' \
      | awk '!seen[$0]++')
    unit_count=$(printf '%s\n' "$units" | grep -c . || true)
    units_display=$(printf '%s\n' "$units" | head -8 | paste -sd ' ' -)
    [ "${unit_count:-0}" -gt 8 ] && units_display+=" +$((unit_count - 8)) more"
    echo "homelab-iac: DRIFT DETECTED in: ${units_display:-unknown}"
    printf '%s\n' "$detail"
    summary="${detail:0:1400}"
    if [ "${#detail}" -gt 1400 ]; then
      summary+=$'\n… trimmed; full diff: journalctl -u homelab-iac-drift'
    fi
    if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
      if curl -fsS -m 10 -H "Content-Type: application/json" \
        --data "$(jq -nc --arg user "$CLEYTIN_USER_ID" --arg summary "$summary" --arg c "🟠 **homelab-iac drift** — ${units_display:-unknown} drifted from code." '{content:("<@"+$user+">\n"+$c+"\n\n"+$summary),allowed_mentions:{users:[$user]}}')" \
        "$DISCORD_WEBHOOK_URL" >/dev/null; then
        notification=delivered
      else
        notification=failed
      fi
    fi
    exit 2
    ;;
  *)
    echo "homelab-iac: drift-check ERROR (exit $code)"
    printf '%s\n' "$out" | sed -E 's/\x1b\[[0-9;]*m//g' | tail -25
    # Alert on errors too — a broken checker (unreachable provider, expired
    # creds, registry down) otherwise looks identical to "no drift".
    if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
      if curl -fsS -m 10 -H "Content-Type: application/json" \
        --data "$(jq -nc --arg user "$CLEYTIN_USER_ID" --arg c "🔴 **homelab-iac drift-check ERROR** (exit $code) — provider unreachable / expired creds / registry down. Investigate." '{content:("<@"+$user+">\n"+$c),allowed_mentions:{users:[$user]}}')" \
        "$DISCORD_WEBHOOK_URL" >/dev/null; then
        notification=delivered
      else
        notification=failed
      fi
    fi
    exit 1
    ;;
esac
