#!/usr/bin/env bash
set -euo pipefail

client_id="${KINDLE_RELEASE_CLIENT_ID:-}"
client_secret="${KINDLE_RELEASE_CLIENT_SECRET:-}"
refresh_token="${GITHUB_APP_MANAGEMENT_REFRESH_TOKEN:-}"

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

printf '%s\n%s' "$access_token" "$next_refresh_token" |
  jq -Rs 'split("\n") | {
    GITHUB_APP_MANAGEMENT_TOKEN: .[0],
    GITHUB_APP_MANAGEMENT_REFRESH_TOKEN: .[1]
  }' |
  bao kv patch -mount=secret home/github-app-management @/dev/stdin >/dev/null

printf %s "$access_token"
