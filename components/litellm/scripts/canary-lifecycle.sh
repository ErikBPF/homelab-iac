#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
UNIT_DIR=$(CDPATH='' cd -- "$SCRIPT_DIR/../environments/home/canary" && pwd)
ADDRESS='litellm_model.this["tf-canary-big-pickle"]'
CONFIRMATION=CREATE_READ_UPDATE_IMPORT_DELETE_TF_CANARY_BIG_PICKLE
TMP=$(mktemp -d "${TMPDIR:-/tmp}/litellm-canary-lifecycle.XXXXXX")
REMOTE_EXISTS=false

cleanup_identity() {
  [[ -f "$TMP/bootstrap-header" ]] || return 0

  if [[ -s "$TMP/provider-key" ]]; then
    jq -n --rawfile key "$TMP/provider-key" \
      '{keys: [($key | rtrimstr("\n"))]}' >"$TMP/delete-key.json"
    curl --silent --show-error --output /dev/null \
      --header @"$TMP/bootstrap-header" --header 'Content-Type: application/json' \
      --data-binary @"$TMP/delete-key.json" "$LITELLM_API_BASE/key/delete" || true
  fi

  if [[ -s "$TMP/provider-user-id" ]]; then
    jq -n --rawfile user_id "$TMP/provider-user-id" \
      '{user_ids: [($user_id | rtrimstr("\n"))]}' >"$TMP/delete-user.json"
    curl --silent --show-error --output /dev/null \
      --header @"$TMP/bootstrap-header" --header 'Content-Type: application/json' \
      --data-binary @"$TMP/delete-user.json" "$LITELLM_API_BASE/user/delete" || true
  fi
}

cleanup() {
  set +e
  cleanup_identity
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  printf 'LiteLLM canary lifecycle FAIL: %s\n' "$1" >&2
  if [[ "$REMOTE_EXISTS" == true ]]; then
    printf 'Canary may still exist. Inspect state, then run this harness with action delete.\n' >&2
  fi
  exit 1
}

require_env() {
  local name=$1
  [[ -n ${!name:-} ]] || fail "required environment variable $name is unset"
}

mint_identity() {
  local http_status user_id
  user_id="terraform-canary-$(date -u +%Y%m%dT%H%M%SZ)-$$"

  printf 'Authorization: Bearer %s\n' "$LITELLM_BOOTSTRAP_KEY" >"$TMP/bootstrap-header"
  chmod 0600 "$TMP/bootstrap-header"
  jq -n --arg user_id "$user_id" '{
    user_id: $user_id,
    user_alias: "terraform-provider-canary",
    user_role: "proxy_admin",
    duration: "15m",
    key_alias: "terraform-provider-canary",
    auto_create_key: true,
    metadata: {purpose: "disposable-provider-lifecycle-canary"}
  }' >"$TMP/new-user.json"

  http_status=$(curl --silent --show-error --output "$TMP/new-user-response.json" \
    --write-out '%{http_code}' --header @"$TMP/bootstrap-header" \
    --header 'Content-Type: application/json' --data-binary @"$TMP/new-user.json" \
    "$LITELLM_API_BASE/user/new")
  [[ $http_status == 2* ]] || fail "disposable provider identity mint returned HTTP $http_status"
  jq -e '.user_role == "proxy_admin" and (.key | type == "string" and length > 0)' \
    "$TMP/new-user-response.json" >/dev/null \
    || fail "disposable provider identity response is incomplete"
  jq -er '.key' "$TMP/new-user-response.json" >"$TMP/provider-key"
  jq -er '.user_id' "$TMP/new-user-response.json" >"$TMP/provider-user-id"
  chmod 0600 "$TMP/provider-key" "$TMP/provider-user-id"
  export LITELLM_API_KEY
  LITELLM_API_KEY=$(<"$TMP/provider-key")
}

run_quiet() {
  local label=$1
  shift
  if ! "$@" >"$TMP/$label.log" 2>&1; then
    fail "$label failed; output suppressed because it may contain sensitive provider data"
  fi
}

assert_no_secret() {
  local file=$1
  if grep -Fq -- "$LITELLM_API_KEY" "$file"; then
    fail "provider credential appeared in captured command output"
  fi
}

write_update_vars() {
  jq -n '{
    models: {
      "tf-canary-big-pickle": {
        custom_llm_provider: "openai",
        base_model: "big-pickle",
        model_api_key: "os.environ/OPENCODE_ZEN_KEY",
        model_api_base: "https://opencode.ai/zen/v1",
        mode: "chat",
        input_cost_per_million_tokens: 0,
        output_cost_per_million_tokens: 0,
        additional_litellm_params: { timeout: "601" },
        context_limit: 200000,
        output_limit: 32000,
        input_modalities: ["text"],
        output_modalities: ["text"],
        supports_reasoning: true,
        supports_tools: true,
        privacy_tier: "non-confidential",
        lifecycle: "canary"
      }
    }
  }' >"$TMP/update.tfvars.json"
}

zero_diff() {
  local label=$1
  shift
  set +e
  terragrunt plan --working-dir "$UNIT_DIR" --non-interactive --no-color \
    -detailed-exitcode "$@" >"$TMP/$label.log" 2>&1
  local status=$?
  set -e
  assert_no_secret "$TMP/$label.log"
  [[ $status -eq 0 ]] || fail "$label expected zero diff, got exit $status"
}

create() {
  run_quiet create terragrunt apply --working-dir "$UNIT_DIR" \
    --non-interactive --no-color -auto-approve
  REMOTE_EXISTS=true
  zero_diff create-zero-diff
}

read_remote() {
  run_quiet read terragrunt plan --working-dir "$UNIT_DIR" \
    --non-interactive --no-color -refresh-only -detailed-exitcode
  assert_no_secret "$TMP/read.log"
}

update() {
  write_update_vars
  run_quiet update terragrunt apply --working-dir "$UNIT_DIR" \
    --non-interactive --no-color -auto-approve -var-file="$TMP/update.tfvars.json"
  zero_diff update-zero-diff -var-file="$TMP/update.tfvars.json"
  run_quiet restore terragrunt apply --working-dir "$UNIT_DIR" \
    --non-interactive --no-color -auto-approve
  zero_diff restore-zero-diff
}

import_model() {
  local model_id
  model_id=$(terragrunt state pull --working-dir "$UNIT_DIR" --non-interactive \
    | jq -er '.resources[] | select(.type == "litellm_model") | .instances[0].attributes.id')
  run_quiet import-state-rm terragrunt state rm --working-dir "$UNIT_DIR" \
    --non-interactive "$ADDRESS"
  run_quiet import terragrunt import --working-dir "$UNIT_DIR" \
    --non-interactive --no-color "$ADDRESS" "$model_id"
  # LiteLLM never returns provider credentials. Import therefore needs one
  # expected reconciliation of the configured os.environ/... reference before
  # the state can be zero-diff without exposing credential material.
  run_quiet import-reconcile terragrunt apply --working-dir "$UNIT_DIR" \
    --non-interactive --no-color -auto-approve
  zero_diff import-zero-diff
}

delete() {
  run_quiet delete terragrunt destroy --working-dir "$UNIT_DIR" \
    --non-interactive --no-color -auto-approve
  REMOTE_EXISTS=false
  run_quiet state-after-delete terragrunt state list --working-dir "$UNIT_DIR" \
    --non-interactive --no-color
  if grep -Fq "$ADDRESS" "$TMP/state-after-delete.log"; then
    fail "canary remains in state after delete"
  fi
}

usage() {
  printf 'usage: %s {run|create|read|update|import|delete}\n' "$0" >&2
  exit 64
}

[[ $# -eq 1 ]] || usage
require_env UNIFI_STATE_PASSPHRASE
require_env LITELLM_API_BASE
require_env LITELLM_BOOTSTRAP_KEY
[[ ${LITELLM_CANARY_LIVE_CONFIRM:-} == "$CONFIRMATION" ]] ||
  fail "set LITELLM_CANARY_LIVE_CONFIRM=$CONFIRMATION for this reviewed live canary"
mint_identity

case $1 in
  run)
    create
    read_remote
    update
    import_model
    delete
    ;;
  create) create ;;
  read) read_remote ;;
  update) update ;;
  import) import_model ;;
  delete) delete ;;
  *) usage ;;
esac

printf 'LiteLLM canary lifecycle PASS: %s\n' "$1"
