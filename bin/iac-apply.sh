#!/usr/bin/env bash
# Apply the merged homelab-iac tree to the live providers.
#
# Called by the discovery `homelab-iac-main-apply` unit after a merge to main.
# Run from a checkout of the merged commit with the provider credentials loaded
# (the NixOS unit decrypts .env.sops and resolves GITHUB_TOKEN first).
#
# Guards, because this mutates live infrastructure without a human in the loop:
#   - a plan containing any destroy is refused,
#   - units in IAC_APPLY_DENYLIST (default: tailscale/acl) are never applied
#     automatically — a wholesale ACL overwrite can cut admin access,
#   - a failed plan or apply stops and alerts; there is no blind retry.
set -uo pipefail
CLEYTIN_USER_ID=1532710143517659356
DENYLIST="${IAC_APPLY_DENYLIST:-tailscale/acl}"

cd "$(dirname "$0")/.." || exit 1
export TG_TF_PATH="${TG_TF_PATH:-tofu}"

# Same state-key mapping as bin/drift-check.sh.
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-${MINIO_TFSTATE_ROOT_USER:-}}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-${MINIO_TFSTATE_ROOT_PASSWORD:-}}"
export TF_VAR_state_passphrase="${TF_VAR_state_passphrase:-${UNIFI_STATE_PASSPHRASE:-}}"

# The monitored scope must stay identical to bin/drift-check.sh; the contract
# test asserts the two --filter lists match.
scope() {
  terragrunt run --all \
    --parallelism 1 \
    --filter '!oracle/compute-telstar' \
    --filter '!components/litellm/environments/home/canary' \
    --filter '!components/authentik/environments/home/aster-identity-reader' \
    --filter '!components/authentik/environments/home/iac-access' \
    --filter '!components/harbor-iam/environments/home/fleet-readers' \
    --filter '!components/harbor-iam/environments/home/production' \
    --filter '!components/harbor-iam/environments/home/project-members' \
    --filter '!components/litellm/environments/home/deepseek-harness-key' \
    --filter '!components/openbao/environments/home/aster-authentik-reader' \
    --filter '!components/openbao/environments/home/authentik-runtime' \
    --filter '!components/openbao/environments/home/deepseek-harness-litellm' \
    --filter '!components/openbao/environments/home/harbor-project-iam' \
    --filter '!components/openbao/environments/home/runtime-secret-foundation' \
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

plan_out=$(scope -- plan -detailed-exitcode -no-color 2>&1)
code=$?
case "$code" in
  0)
    echo "homelab-iac apply: no changes at $(git rev-parse --short HEAD)"
    exit 0
    ;;
  2) ;;
  *)
    printf '%s\n' "$plan_out" | sed -E 's/\x1b\[[0-9;]*m//g' | tail -20
    alert "🔴 **merged-main plan failed** (exit $code) — nothing applied."
    exit 1
    ;;
esac

# Per-unit evidence, attributed so the refusals can name their units.
detail=$(printf '%s\n' "$plan_out" | sed -E 's/\x1b\[[0-9;]*m//g' \
  | sed -nE 's/^.*STDOUT \[([^]]+)\] tofu: (.*)$/\1\t\2/p' \
  | awk -F'\t' '$2 ~ /^(Plan:|  *(~|\+|-|#) )/ && $2 !~ /^ *# \(/' || true)
changed=$(printf '%s\n' "$detail" | cut -f1 | awk '!seen[$0]++' | paste -sd ' ' -)

destroys=$(printf '%s\n' "$detail" \
  | awk -F'\t' '$2 ~ /^Plan: / && $2 !~ /0 to destroy/ { print $1 }' | paste -sd ' ' -)
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

apply_out=$(scope -- apply -auto-approve -no-color 2>&1)
code=$?
if [ "$code" -ne 0 ]; then
  printf '%s\n' "$apply_out" | sed -E 's/\x1b\[[0-9;]*m//g' | tail -20
  alert "🔴 **merged-main apply failed** (exit $code) in ${changed:-unknown}. Retry is manual."
  exit 1
fi

alert "🟢 **merged-main applied** ${changed:-no-op} at $(git rev-parse --short HEAD)"
