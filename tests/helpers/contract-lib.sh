#!/usr/bin/env bash

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local file=$1 pattern=$2 diagnostic=$3
  grep -Eq -- "$pattern" "$file" || fail "$diagnostic"
}

assert_file_excludes() {
  local file=$1 pattern=$2 diagnostic=$3
  if grep -REiq --exclude-dir=.terraform --exclude-dir=.terragrunt-cache -- "$pattern" "$file"; then
    fail "$diagnostic"
  fi
}

tracked_state_keys() {
  git -C "$REPO_ROOT" ls-files '*/terragrunt.hcl' \
    | LC_ALL=C sort \
    | awk '{ dir=$0; sub("/terragrunt.hcl$", "", dir); print dir " " dir "/terraform.tfstate" }'
}

shared_root_boundary_valid() {
  local file=$1 generates
  generates=$(sed -nE 's/^[[:space:]]*generate[[:space:]]+"([^"]+)".*/\1/p' "$file")

  [[ "$generates" == "encryption" ]] || return 1
  ! grep -Eq '^[[:space:]]*provider[[:space:]]+"' "$file" || return 1
  ! grep -Eiq '^[[:space:]]*(host|url|endpoint|api_key|token|password|secret|source)[[:space:]]*=' "$file"
}

render_adguard_contract() {
  local output=$1 render_json
  render_json="$TEST_TMP/adguard-render.json"

  UNIFI_STATE_PASSPHRASE='contract-dummy-value' \
    terragrunt render --json --non-interactive --no-color \
      --working-dir "$REPO_ROOT/adguard/filtering" >"$render_json"

  jq --arg root "$REPO_ROOT" -S '
    {
      remote_state: {
        backend: .remote_state.backend,
        config: .remote_state.config,
        generate: .remote_state.generate
      },
      terraform: {
        source: (.terraform.source | sub("^" + $root; "<REPO>"))
      },
      generate: {
        encryption: {
          path: .generate.encryption.path,
          if_exists: .generate.encryption.if_exists,
          contents: .generate.encryption.contents
        },
        provider: {
          path: .generate.provider.path,
          if_exists: .generate.provider.if_exists,
          contents: .generate.provider.contents
        }
      },
      input_keys: (.inputs | keys)
    }
  ' "$render_json" >"$output"
}

render_litellm_contract() {
  local output=$1 render_json="$TEST_TMP/litellm-render.json"

  UNIFI_STATE_PASSPHRASE='contract-dummy-value' \
  LITELLM_API_BASE='http://127.0.0.1:9' \
  LITELLM_API_KEY='contract-native-api-key' \
  LITELLM_TERRAFORM_ADMIN_KEY='contract-obsolete-admin-key' \
    terragrunt render --json --non-interactive --no-color \
      --working-dir "$REPO_ROOT/components/litellm/environments/home/canary" \
      >"$render_json"

  if grep -Eq 'contract-(native-api-key|obsolete-admin-key)' "$render_json"; then
    fail "S02 RED: rendered provider configuration exposes an API/admin key"
  fi

  jq --arg root "$REPO_ROOT" -S '
    {
      remote_state: {
        backend: .remote_state.backend,
        config: .remote_state.config,
        generate: .remote_state.generate
      },
      terraform: {
        source: (.terraform.source | sub("^" + $root; "<REPO>"))
      },
      generate_names: (.generate | keys),
      models: .inputs.models
    }
  ' "$render_json" >"$output"
}
