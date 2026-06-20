#!/usr/bin/env bash
# Drift detection for the whole homelab-iac repo: plan every Terragrunt unit and
# report if live infra has drifted from code. Exit 0 = clean, 2 = drift, 1 = err.
#
# Run from a host with LAN/tailnet reach to the providers (UDM, AdGuard, …) and
# the creds loaded (devenv loads .env; or sops-decrypt .env.sops first).
# Optional: set NTFY_URL to a full ntfy topic URL to get alerted on drift.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
export TG_TF_PATH="${TG_TF_PATH:-tofu}"

out=$(terragrunt run --all plan -detailed-exitcode --terragrunt-non-interactive -no-color 2>&1)
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
    if [ -n "${NTFY_URL:-}" ]; then
      curl -s -H "Title: homelab-iac drift" -H "Priority: high" -H "Tags: warning" \
        -d "Tailscale/UniFi/Cloudflare/AdGuard config drifted from code. Run a plan." \
        "$NTFY_URL" >/dev/null || true
    fi
    exit 2
    ;;
  *)
    echo "homelab-iac: drift-check ERROR (exit $code)"
    printf '%s\n' "$out" | sed -E 's/\x1b\[[0-9;]*m//g' | tail -25
    exit 1
    ;;
esac
