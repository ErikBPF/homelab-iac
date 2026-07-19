#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${repo}/.env"
sops_file="${repo}/.env.sops"

read_value() {
  sed -n "s/^$1=//p" "${env_file}"
}

client_id="$(read_value KINDLE_RELEASE_CLIENT_ID)"
client_secret="$(read_value KINDLE_RELEASE_CLIENT_SECRET)"
refresh_token="$(read_value GITHUB_APP_MANAGEMENT_REFRESH_TOKEN)"

[[ -n "${client_id}" && -n "${client_secret}" && -n "${refresh_token}" ]] || {
  echo "missing Kindle release OAuth refresh inputs" >&2
  exit 1
}

response="$(
  curl -fsS -X POST \
    -H 'Accept: application/json' \
    https://github.com/login/oauth/access_token \
    --data-urlencode "client_id=${client_id}" \
    --data-urlencode "client_secret=${client_secret}" \
    --data-urlencode "grant_type=refresh_token" \
    --data-urlencode "refresh_token=${refresh_token}"
)"

access_token="$(jq -r '.access_token // empty' <<<"${response}")"
next_refresh_token="$(jq -r '.refresh_token // empty' <<<"${response}")"
[[ -n "${access_token}" && -n "${next_refresh_token}" ]] || {
  jq '{error,error_description}' <<<"${response}" >&2
  exit 1
}

printf '%s' "${access_token}" | jq -Rs . |
  sops set --input-type dotenv --output-type dotenv --value-stdin \
    "${sops_file}" '["GITHUB_APP_MANAGEMENT_TOKEN"]'
printf '%s' "${next_refresh_token}" | jq -Rs . |
  sops set --input-type dotenv --output-type dotenv --value-stdin \
    "${sops_file}" '["GITHUB_APP_MANAGEMENT_REFRESH_TOKEN"]'
sops decrypt --input-type dotenv --output-type dotenv \
  --output "${env_file}" "${sops_file}"
chmod 600 "${env_file}" "${sops_file}"

echo "GitHub App management token refreshed"
