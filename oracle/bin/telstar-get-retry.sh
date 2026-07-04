#!/usr/bin/env bash
# Persistent telstar A1 CREATE retry for discovery (always-on). Retries every
# 60s for up to 7 days until Oracle free-tier A1 capacity frees ("Out of host
# capacity" is intermittent in sa-saopaulo-1). Run as a systemd --user service
# (erik) with linger so it survives reboots.
set -uo pipefail
export PATH="/run/current-system/sw/bin:$HOME/.nix-profile/bin:/usr/bin:/bin:$PATH"
REPO="$HOME/homelab-iac"
# discovery's `tofu` is a tenv shim — let it auto-install the pinned OpenTofu.
export TENV_AUTO_INSTALL=true

# Decrypt the sops dotenv ONCE and export the creds terragrunt needs (OCI signing
# key, MinIO S3 backend, state passphrase). sops exec-env can't set --input-type
# and .env.sops's ".sops" extension isn't auto-detected as dotenv, so decrypt via
# `sops -d --input-type dotenv` into a 600 temp, parse (quote-stripped), wipe it.
TMPENV="$(mktemp)"; chmod 600 "$TMPENV"
sops -d --input-type dotenv --output-type dotenv "$REPO/.env.sops" > "$TMPENV"
# NB: split on the FIRST '=' via parameter expansion, NOT `IFS='=' read` — the
# latter treats '=' as a delimiter and eats base64 padding ('=') off the end of
# OCI_private_key_b64, corrupting it.
while IFS= read -r line; do
  k="${line%%=*}"; v="${line#*=}"
  v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
  export "$k=$v"
done < <(grep -E '^(OCI_[A-Za-z0-9_]+|MINIO_TFSTATE_[A-Za-z0-9_]+|UNIFI_STATE_PASSPHRASE)=' "$TMPENV")
shred -u "$TMPENV" 2>/dev/null || rm -f "$TMPENV"
export AWS_ACCESS_KEY_ID="${MINIO_TFSTATE_ROOT_USER:-}"
export AWS_SECRET_ACCESS_KEY="${MINIO_TFSTATE_ROOT_PASSWORD:-}"
export TG_TF_PATH="$(command -v tofu)"
# SSH pubkey injected into the telstar instance (the laptop's key, copied here —
# a pubkey is not secret). Lets the deploy host reach telstar for just deploy-telstar.
export OCI_SSH_PUBKEY_FILE="$HOME/telstar-ssh-key.pub"
cd "$REPO/oracle/compute-telstar"

end=$(( $(date +%s) + 7 * 24 * 3600 ))
sleep_s="${SLEEP_SECONDS:-60}"
max_iter="${MAX_ITER:-0}"   # 0 = run to 7-day deadline; >0 caps attempts (smoke test)
n=0
while [ "$(date +%s)" -lt "$end" ]; do
  n=$((n + 1))
  echo "=== telstar create attempt $n  $(date -u '+%F %T')Z ==="
  log=$(mktemp)
  if terragrunt apply -auto-approve >"$log" 2>&1; then
    echo ">>> TELSTAR CREATED on attempt $n"
    grep -iE "public_ip|instance_ocid" "$log" | tail -3
    echo ">>> next: set public_ip as ip_telstar in desktop-nixos/justfile, then just deploy-telstar"
    rm -f "$log"; exit 0
  fi
  if grep -q "Out of host capacity" "$log"; then
    echo "attempt $n: Out of host capacity — retry in ${sleep_s}s"
  else
    echo ">>> attempt $n FAILED (non-capacity) — stopping. Tail:"
    tail -25 "$log"; rm -f "$log"; exit 1
  fi
  rm -f "$log"
  [ "$max_iter" -gt 0 ] && [ "$n" -ge "$max_iter" ] && { echo ">>> smoke-test iter cap ($max_iter)"; exit 3; }
  sleep "$sleep_s"
done
echo ">>> gave up after $n attempts (~7 days, no A1 capacity)"; exit 2
