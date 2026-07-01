#!/usr/bin/env bash
# Retry the voyager A1 shape upgrade (1 OCPU/6 GB -> 2 OCPU/12 GB) until the
# free-tier capacity for the larger shape frees up. Run AFTER voyager exists at
# 1 OCPU — this resizes an existing instance (in-place, reboots it), it does not
# create one.
#
# Usage (from oracle/compute, inside the devenv/direnv env):
#   OCI_OCPUS=2 OCI_MEMORY_GBS=12 bash ../bin/upgrade-retry.sh
set -uo pipefail

export OCI_OCPUS="${OCI_OCPUS:-2}"
export OCI_MEMORY_GBS="${OCI_MEMORY_GBS:-12}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE/../compute"

n=0
max="${MAX_ATTEMPTS:-240}"
sleep_s="${SLEEP_SECONDS:-300}"
log="$(mktemp)"

while [ "$n" -lt "$max" ]; do
  n=$((n + 1))
  echo "=== upgrade attempt $n -> ${OCI_OCPUS} OCPU / ${OCI_MEMORY_GBS} GB  $(date -u '+%F %T')Z ==="
  if terragrunt apply -auto-approve >"$log" 2>&1; then
    echo ">>> UPGRADE APPLIED on attempt $n"
    terragrunt output 2>&1 | grep -iE "public_ip|instance_ocid" || true
    exit 0
  fi
  if grep -q "Out of host capacity" "$log"; then
    echo "attempt $n: still Out of host capacity — retrying in ${sleep_s}s"
  else
    echo ">>> attempt $n FAILED for a non-capacity reason — stopping. Tail:"
    tail -20 "$log"
    exit 1
  fi
  sleep "$sleep_s"
done
echo ">>> gave up after $n attempts (no capacity for the larger shape)"
exit 2
