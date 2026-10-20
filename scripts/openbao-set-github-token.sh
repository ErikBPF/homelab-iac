#!/usr/bin/env bash
# Write the GitHub CLI token into OpenBao: secret/iac/github, field `token`.
#
# The value is read from stdin so it never lands in argv, shell history, a
# repo, or Terraform state. Rotation uses the same command.
#
#   printf '%s' "$NEW_TOKEN" | BAO_ADDR=... BAO_TOKEN=... \
#     scripts/openbao-set-github-token.sh
#
# BAO_TOKEN must be able to write secret/data/iac/github. That is deliberately
# not granted to the routine iac AppRole: the value is written out of band with
# the break-glass root token (desktop-nixos sops `vault_root_token`), never by
# an automated apply. See docs/reference/key-rotation.md for the ordering.
set -euo pipefail

: "${BAO_ADDR:?set BAO_ADDR (e.g. http://100.103.52.100:8200)}"
: "${BAO_TOKEN:?set BAO_TOKEN (root or a write-capable token)}"

token=$(cat)
if [ -z "$token" ]; then
  echo "empty token on stdin" >&2
  exit 1
fi

# jq reads the value from stdin too, keeping it out of the process table.
payload=$(printf '%s' "$token" | jq -Rs '{data: {token: .}}')
unset token

curl --fail --silent --show-error \
  --header "X-Vault-Token: $BAO_TOKEN" \
  --request POST \
  --data "$payload" \
  "$BAO_ADDR/v1/secret/data/iac/github" >/dev/null
unset payload BAO_TOKEN

echo ":: secret/iac/github token written"
