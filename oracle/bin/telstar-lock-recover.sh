#!/usr/bin/env bash
set -euo pipefail

lock_id="${1:-}"
[[ "$lock_id" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || {
  echo "lock_id must be an exact UUID" >&2
  exit 2
}

if pgrep -f '(tofu|terragrunt).*compute-telstar' >/dev/null; then
  echo "refusing recovery: active Telstar IaC process" >&2
  exit 1
fi

REPO="${REPO:-$HOME/homelab-iac}"
export OCI_SSH_PUBKEY_FILE="${OCI_SSH_PUBKEY_FILE:-$HOME/telstar-ssh-key.pub}"
tmpenv="$(mktemp)"
trap 'shred -u "$tmpenv" 2>/dev/null || rm -f "$tmpenv"' EXIT
chmod 600 "$tmpenv"
sops -d --input-type dotenv --output-type dotenv "$REPO/.env.sops" > "$tmpenv"
while IFS= read -r line; do
  k="${line%%=*}"; v="${line#*=}"
  v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
  export "$k=$v"
done < <(grep -E '^(OCI_[A-Za-z0-9_]+|MINIO_TFSTATE_[A-Za-z0-9_]+|UNIFI_STATE_PASSPHRASE)=' "$tmpenv")
export AWS_ACCESS_KEY_ID="${MINIO_TFSTATE_ROOT_USER:-}"
export AWS_SECRET_ACCESS_KEY="${MINIO_TFSTATE_ROOT_PASSWORD:-}"
TG_TF_PATH="$(command -v tofu)"
export TG_TF_PATH

cd "$REPO/oracle/compute-telstar"
set +e
lock_output="$(terragrunt plan -lock-timeout=0s -input=false -no-color 2>&1)"
plan_rc=$?
set -e
[ "$plan_rc" -ne 0 ] || { echo "refusing recovery: state is not locked" >&2; exit 1; }
grep -Fq 'Error acquiring the state lock' <<<"$lock_output"
grep -Fq "ID:        $lock_id" <<<"$lock_output"
grep -Fq 'Path:      tofu-state/oracle/compute-telstar/terraform.tfstate' <<<"$lock_output"
created="$(sed -n 's/^  Created:   //p' <<<"$lock_output" | head -1)"
[ -n "$created" ]
age=$(( $(date +%s) - $(date -d "$created" +%s) ))
[ "$age" -ge 240 ] || { echo "refusing recovery: lock is younger than 240 seconds" >&2; exit 1; }

terragrunt force-unlock -force "$lock_id"
