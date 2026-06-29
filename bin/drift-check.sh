#!/usr/bin/env bash
# Drift detection for the whole homelab-iac repo: plan every Terragrunt unit and
# report if live infra has drifted from code. Exit 0 = clean, 2 = drift, 1 = err.
#
# Run from a host with LAN/tailnet reach to the providers (UDM, AdGuard, …) and
# the creds loaded (devenv loads .env; or sops-decrypt .env.sops first).
# Optional: set DISCORD_WEBHOOK_URL to a Discord webhook to get alerted on drift.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
export TG_TF_PATH="${TG_TF_PATH:-tofu}"

# State lives in MinIO (S3 backend). The bucket creds are MINIO_TFSTATE_* in the
# secret store; OpenTofu's s3 backend reads AWS_*. Map them if not already set.
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-${MINIO_TFSTATE_ROOT_USER:-}}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-${MINIO_TFSTATE_ROOT_PASSWORD:-}}"

# Measure drift against the latest committed IaC, not a stale local checkout.
git pull --ff-only 2>/dev/null || true

out=$(terragrunt run --all --non-interactive -- plan -detailed-exitcode -no-color 2>&1)
code=$?

case "$code" in
  0)
    echo "homelab-iac: no drift — live infra matches code."
    ;;
  2)
    summary=$(printf '%s\n' "$out" | sed -E 's/\x1b\[[0-9;]*m//g' \
      | grep -aE 'Plan:|will be (updated|created|destroyed)|# ' | head -40)
    echo "homelab-iac: DRIFT DETECTED"
    printf '%s\n' "$summary"
    if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
      curl -fsS -m 10 -H "Content-Type: application/json" \
        --data "$(jq -nc --arg c "🟠 **homelab-iac drift** — Tailscale/UniFi/Cloudflare/AdGuard config drifted from code. Run a plan." '{content:$c}')" \
        "$DISCORD_WEBHOOK_URL" >/dev/null || true
    fi
    exit 2
    ;;
  *)
    echo "homelab-iac: drift-check ERROR (exit $code)"
    printf '%s\n' "$out" | sed -E 's/\x1b\[[0-9;]*m//g' | tail -25
    # Alert on errors too — a broken checker (unreachable provider, expired
    # creds, registry down) otherwise looks identical to "no drift".
    if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
      curl -fsS -m 10 -H "Content-Type: application/json" \
        --data "$(jq -nc --arg c "🔴 **homelab-iac drift-check ERROR** (exit $code) — provider unreachable / expired creds / registry down. Investigate." '{content:$c}')" \
        "$DISCORD_WEBHOOK_URL" >/dev/null || true
    fi
    exit 1
    ;;
esac
