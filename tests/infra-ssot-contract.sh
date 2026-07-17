#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)
export REPO_ROOT
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/infra-ssot-contract.XXXXXX")
export TEST_TMP
trap 'rm -rf "$TEST_TMP"' EXIT

# shellcheck source=tests/helpers/contract-lib.sh
source "$SCRIPT_DIR/helpers/contract-lib.sh"

if [[ $# -ne 1 ]]; then
  printf '%s\n' "usage: tests/infra-ssot-contract.sh {s01|s02|s03|s04|s05|all}" >&2
  exit 64
fi

check_s01() {
  local shared="$REPO_ROOT/_shared/root.hcl"
  local canary_root="$REPO_ROOT/adguard/root.hcl"
  local canary_unit="$REPO_ROOT/adguard/filtering/terragrunt.hcl"
  local expected actual normalized fixture

  [[ -f "$shared" ]] \
    || fail "S01 RED: canonical shared root missing or canary does not inherit it"

  assert_file_contains "$canary_unit" '_shared/root\.hcl' \
    "S01 RED: canonical shared root missing or canary does not inherit it"
  assert_file_excludes "$canary_root" '^[[:space:]]*remote_state[[:space:]]*\{' \
    "S01 RED: canary component still owns copied backend behavior"
  assert_file_excludes "$canary_root" 'generate[[:space:]]+"encryption"' \
    "S01 RED: canary component still owns copied encryption behavior"

  assert_file_contains "$shared" '^[[:space:]]*remote_state[[:space:]]*\{' \
    "S01 RED: shared root does not own backend behavior"
  assert_file_contains "$shared" 'state_key[[:space:]]*=[[:space:]]*trimprefix\(path_relative_to_include\(\),[[:space:]]*"\.\./"\)' \
    "S01 RED: shared backend key does not normalize its sibling-directory hop"
  assert_file_contains "$shared" 'key[[:space:]]*=[[:space:]]*"\$\{local\.state_key\}/terraform\.tfstate"' \
    "S01 RED: shared backend key does not preserve normalized unit identity"
  assert_file_contains "$shared" 'key_provider[[:space:]]+"pbkdf2"' \
    "S01 RED: shared encryption lacks PBKDF2"
  assert_file_contains "$shared" 'method[[:space:]]+"aes_gcm"' \
    "S01 RED: shared encryption lacks AES-GCM"
  assert_file_contains "$shared" '^[[:space:]]*state[[:space:]]*\{' \
    "S01 RED: shared encryption does not cover state"
  assert_file_contains "$shared" '^[[:space:]]*plan[[:space:]]*\{' \
    "S01 RED: shared encryption does not cover plans"
  shared_root_boundary_valid "$shared" \
    || fail "S01 RED: shared root owns unexpected generate/provider/credential/endpoint semantics"

  # Meta-check the boundary itself: an arbitrary provider generate must be
  # rejected regardless of provider name.
  cp "$shared" "$TEST_TMP/mutated-shared-root.hcl"
  printf '\ngenerate "unexpected-provider" { contents = "provider \\\"example\\\" {}" }\n' \
    >>"$TEST_TMP/mutated-shared-root.hcl"
  if shared_root_boundary_valid "$TEST_TMP/mutated-shared-root.hcl"; then
    fail "S01 RED: shared-root ownership guard accepts unexpected generate blocks"
  fi

  expected=$(cat "$SCRIPT_DIR/fixtures/state-keys.txt")
  actual=$(tracked_state_keys)
  [[ "$actual" == "$expected" ]] \
    || fail "S01 RED: tracked unit set no longer matches preserved state-key fixture"

  fixture=${CONTRACT_FIXTURE_OVERRIDE:-"$SCRIPT_DIR/fixtures/adguard-filtering-render.json"}
  normalized="$TEST_TMP/adguard-contract.json"
  render_adguard_contract "$normalized"

  if grep -Eq 'contract-dummy-value|state_passphrase"[[:space:]]*:' "$normalized"; then
    fail "S01 RED: normalized rendered contract exposes secret material"
  fi
  if ! diff -u "$fixture" "$normalized" >&2; then
    fail "S01 RED: rendered backend/module/provider/encryption/input contract changed"
  fi

  printf '%s\n' "S01 PASS: shared root inherited; backend key stable; generated contract stable"
}

check_s02() {
  local component="$REPO_ROOT/components/litellm"
  local root="$component/root.hcl"
  local versions="$component/modules/model/versions.tf"
  local variables="$component/modules/model/variables.tf"
  local main="$component/modules/model/main.tf"
  local unit="$component/environments/home/canary/terragrunt.hcl"
  local lifecycle="$component/scripts/canary-lifecycle.sh"
  local normalized

  [[ -f "$root" && -f "$versions" && -f "$variables" && -f "$main" && -f "$unit" && -f "$lifecycle" ]] \
    || fail "S02 RED: LiteLLM Terraform canary contract not implemented"

  assert_file_contains "$versions" 'source[[:space:]]*=[[:space:]]*"registry\.terraform\.io/ErikBPF/litellm"' \
    "S02 RED: LiteLLM provider must use the explicit Terraform Registry hostname"
  assert_file_contains "$versions" 'version[[:space:]]*=[[:space:]]*"[^\"]*[0-9][^\"]*"' \
    "S02 RED: LiteLLM provider version is not constrained"
  assert_file_contains "$variables" 'variable[[:space:]]+"models"' \
    "S02 RED: typed model map is missing"
  assert_file_contains "$main" 'for_each[[:space:]]*=[[:space:]]*var\.models' \
    "S02 RED: model addressing is not keyed by logical alias"
  assert_file_contains "$main" 'model_name[[:space:]]*=[[:space:]]*each\.key' \
    "S02 RED: official flat schema model_name is missing"
  assert_file_contains "$main" 'custom_llm_provider[[:space:]]*=[[:space:]]*each\.value\.custom_llm_provider' \
    "S02 RED: official flat schema custom_llm_provider is missing"
  assert_file_contains "$main" 'base_model[[:space:]]*=[[:space:]]*each\.value\.base_model' \
    "S02 RED: official flat schema base_model is missing"
  assert_file_excludes "$main" '^[[:space:]]*litellm_params[[:space:]]*=' \
    "S02 RED: nonexistent litellm_params block used with provider v0.2.2"
  assert_file_excludes "$main" '^[[:space:]]*model_info[[:space:]]*=' \
    "S02 RED: nonexistent model_info block used with provider v0.2.2"
  assert_file_excludes "$root" '(api_key|admin_key)[[:space:]]*=' \
    "S02 RED: provider writes raw API/admin key instead of native environment auth"
  assert_file_excludes "$root" 'LITELLM_TERRAFORM_ADMIN_KEY' \
    "S02 RED: provider must use native LITELLM_API_BASE and LITELLM_API_KEY environment auth"
  assert_file_contains "$unit" 'tf-canary-big-pickle[[:space:]]*=' \
    "S02 RED: stable Big Pickle canary alias is missing"
  assert_file_contains "$unit" 'custom_llm_provider[[:space:]]*=[[:space:]]*"openai"' \
    "S02 RED: Big Pickle must use the OpenAI-compatible provider"
  assert_file_contains "$unit" 'base_model[[:space:]]*=[[:space:]]*"big-pickle"' \
    "S02 RED: Big Pickle base_model must be bare; provider composes its prefix"
  assert_file_excludes "$unit" 'base_model[[:space:]]*=[[:space:]]*"[^"[:space:]]+/' \
    "S02 RED: canary base_model incorrectly includes a provider prefix"
  assert_file_contains "$unit" 'model_api_key[[:space:]]*=[[:space:]]*"os\.environ/OPENCODE_ZEN_KEY"' \
    "S02 RED: Zen canary key must be an OPENCODE_ZEN_KEY environment reference"
  assert_file_contains "$unit" 'model_api_base[[:space:]]*=[[:space:]]*"https://opencode\.ai/zen/v1"' \
    "S02 RED: Big Pickle canary must target the OpenCode Zen API"
  assert_file_contains "$unit" 'lifecycle[[:space:]]*=' \
    "S02 RED: canary lifecycle is implicit"
  assert_file_contains "$unit" 'privacy(_tier)?[[:space:]]*=' \
    "S02 RED: canary privacy tier is missing"

  assert_file_contains "$variables" 'output_limit[[:space:]]*<=[[:space:]]*model\.context_limit' \
    "S02 RED: output/context validation is missing"
  assert_file_contains "$variables" 'input_cost_per_million_tokens[[:space:]]*>=[[:space:]]*0' \
    "S02 RED: input price validation is missing"
  assert_file_contains "$variables" 'output_cost_per_million_tokens[[:space:]]*>=[[:space:]]*0' \
    "S02 RED: output price validation is missing"
  assert_file_contains "$variables" 'contains\(\["chat",[[:space:]]*"completion",[[:space:]]*"embedding"\],[[:space:]]*model\.mode\)' \
    "S02 RED: model mode closed-set validation is missing"
  assert_file_excludes "$main" 'each\.value\.(privacy_tier|lifecycle)' \
    "S02 RED: governance-only metadata is passed to provider fields"
  assert_file_contains "$lifecycle" 'terragrunt[[:space:]]+import' \
    "S02 RED: lifecycle harness does not exercise provider import"
  assert_file_contains "$lifecycle" 'import-reconcile' \
    "S02 RED: import does not reconcile the unreadable credential reference"
  assert_file_contains "$lifecycle" 'import-zero-diff' \
    "S02 RED: import lifecycle has no post-reconciliation zero-diff gate"
  assert_file_contains "$lifecycle" 'require_env[[:space:]]+LITELLM_BOOTSTRAP_KEY' \
    "S02 RED: live canary does not require explicit bootstrap auth"
  assert_file_contains "$lifecycle" '/user/new' \
    "S02 RED: live canary does not mint a disposable provider identity"
  assert_file_contains "$lifecycle" 'proxy_admin' \
    "S02 RED: disposable provider identity lacks model-admin authority"
  assert_file_contains "$lifecycle" '/key/delete' \
    "S02 RED: live canary does not revoke its disposable key"
  assert_file_contains "$lifecycle" '/user/delete' \
    "S02 RED: live canary does not delete its disposable user"
  assert_file_excludes "$lifecycle" 'require_env[[:space:]]+LITELLM_API_KEY' \
    "S02 RED: live canary still requires a manually pre-created provider key"

  normalized="$TEST_TMP/litellm-contract.json"
  render_litellm_contract "$normalized"
  if ! diff -u "$SCRIPT_DIR/fixtures/litellm-canary-render.json" "$normalized" >&2; then
    fail "S02 RED: rendered LiteLLM alias/state/module/metadata contract changed"
  fi

  printf '%s\n' "S02 PASS: official provider pinned; canary model contract valid; no secret material"
}

check_s03() {
  local renovate="$REPO_ROOT/renovate.json"
  local workflow="$REPO_ROOT/.github/workflows/zen-catalog.yml"
  local updater="$REPO_ROOT/bin/update-zen-catalog.sh"
  local output="$TEST_TMP/zen-catalog.json"

  [[ -f "$renovate" && -f "$workflow" && -x "$updater" ]] \
    || fail "S03 RED: catalog and dependency automation not implemented"

  jq -e . "$renovate" >/dev/null \
    || fail "S03 RED: Renovate configuration is not valid JSON"
  jq -e '
    ((.enabledManagers // []) | index("terraform") != null) and
    ((.enabledManagers // []) | index("dockerfile") != null) and
    (.automerge != true)
  ' "$renovate" >/dev/null \
    || fail "S03 RED: Renovate managers or manual-merge policy are incomplete"

  assert_file_contains "$workflow" '^[[:space:]]*schedule:' \
    "S03 RED: Zen catalog workflow has no schedule"
  assert_file_contains "$workflow" '^[[:space:]]*workflow_dispatch:' \
    "S03 RED: Zen catalog workflow cannot be manually dispatched"
  assert_file_contains "$workflow" 'pull-requests:[[:space:]]*write' \
    "S03 RED: Zen catalog workflow cannot open a review PR"
  assert_file_contains "$workflow" 'bin/update-zen-catalog\.sh' \
    "S03 RED: Zen catalog workflow does not use the repository updater"
  assert_file_excludes "$workflow" '(terragrunt|tofu)[[:space:]]+(apply|plan|import)|automerge' \
    "S03 RED: catalog discovery can mutate infrastructure or auto-merge"

  env -i PATH="$PATH" HOME="$TEST_TMP/home" \
    NO_PROXY='*' HTTPS_PROXY='http://127.0.0.1:9' HTTP_PROXY='http://127.0.0.1:9' \
    "$updater" --input "$SCRIPT_DIR/fixtures/zen-catalog-source.json" --output "$output"
  diff -u "$SCRIPT_DIR/fixtures/zen-catalog-normalized.json" "$output" >&2 \
    || fail "S03 RED: normalized Zen catalog is not deterministic"

  jq -e '
    .source == "opencode-zen" and
    (.models | length) == 1 and
    (.models[0] |
      (.source_id | type == "string") and
      (.context_limit | type == "number") and
      (.output_limit | type == "number") and
      (.input_price_per_million | type == "number") and
      (.output_price_per_million | type == "number") and
      (.supports_reasoning | type == "boolean") and
      (.supports_tools | type == "boolean") and
      (.is_free | type == "boolean") and
      .privacy_tier == "unknown" and
      .lifecycle == "discovered")
  ' "$output" >/dev/null \
    || fail "S03 RED: normalized Zen catalog schema is incomplete"

  printf '%s\n' "S03 PASS: dependencies managed; Zen catalog update deterministic and review-only"
}

check_s04() {
  local component="$REPO_ROOT/components/litellm"
  local versions="$component/modules/model/versions.tf"
  local variables="$component/modules/model/variables.tf"
  local main="$component/modules/model/main.tf"
  local fork="$component/provider"
  local pin="$component/provider-source-lock.json"
  local fixture="$SCRIPT_DIR/fixtures/litellm-provider-roundtrip.json"
  local provider_source normalized_source field

  assert_file_contains "$variables" 'team_id[[:space:]]*=[[:space:]]*optional\(string,[[:space:]]*""\)' \
    "S04 RED: team_id is not a future-compatible optional model input"
  assert_file_contains "$main" 'team_id[[:space:]]*=[[:space:]]*each\.value\.team_id' \
    "S04 RED: model resource does not preserve future team compatibility"
  for mapping in \
    'max_input_tokens[[:space:]]*=[[:space:]]*each\.value\.context_limit' \
    'max_output_tokens[[:space:]]*=[[:space:]]*each\.value\.output_limit' \
    'input_modalities[[:space:]]*=[^\n]*each\.value\.input_modalities' \
    'output_modalities[[:space:]]*=[^\n]*each\.value\.output_modalities' \
    'supports_reasoning[[:space:]]*=[[:space:]]*each\.value\.supports_reasoning' \
    'supports_function_calling[[:space:]]*=[[:space:]]*each\.value\.supports_tools'; do
    assert_file_contains "$main" "$mapping" \
      "S04 RED: homelab model_info mapping is incomplete"
  done
  assert_file_excludes "$main" 'each\.value\.(privacy_tier|lifecycle)' \
    "S04 RED: local governance metadata is incorrectly sent to LiteLLM"

  provider_source=$(sed -nE 's/^[[:space:]]*source[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$versions" | head -1)
  normalized_source=${provider_source#registry.terraform.io/}
  [[ -n "$normalized_source" && "$normalized_source" != "BerriAI/litellm" ]] \
    || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"

  [[ -f "$fork/go.mod" && -f "$fork/go.sum" && -f "$pin" ]] \
    || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"
  jq -e '
    (.source_repository | type == "string" and length > 0) and
    (.commit | test("^[0-9a-f]{40}$")) and
    (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+")) and
    (.artifact_sha256 | test("^[0-9a-f]{64}$"))
  ' "$pin" >/dev/null \
    || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"

  grep -REq --include='*.go' '(Importer|ImportStatePassthroughContext|ResourceWithImportState)' "$fork" \
    || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"
  for field in team_id max_input_tokens max_output_tokens input_modalities output_modalities supports_reasoning supports_function_calling; do
    grep -REq --include='*.go' "[\"\x60]${field}[\"\x60]" "$fork" \
      || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"
  done
  grep -REq --include='*.go' '(model_info|ModelInfo)' "$fork" \
    || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"
  grep -REq --include='*_test.go' '(Import|import).*(Read|read|State|state)' "$fork" \
    || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"
  grep -REq --include='*_test.go' '(zero.?diff|round.?trip|read.?back|perpetual)' "$fork" \
    || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"
  grep -REq --include='*_test.go' '(team_id|TeamID)' "$fork" \
    || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"

  assert_file_contains "$variables" 'team_id[[:space:]]*=[[:space:]]*optional\(string,[[:space:]]*""\)' \
    "S04 RED: team_id is not a future-compatible optional model input"
  assert_file_contains "$main" 'team_id[[:space:]]*=[[:space:]]*each\.value\.team_id' \
    "S04 RED: model resource does not preserve future team compatibility"
  assert_file_excludes "$main" 'additional_litellm_params[^\n]*(context_limit|output_limit|modalities|reasoning|tools|privacy|lifecycle)' \
    "S04 RED: metadata is disguised as LiteLLM request parameters"
  assert_file_excludes "$main" 'each\.value\.(privacy_tier|lifecycle)' \
    "S04 RED: local governance metadata is incorrectly sent to LiteLLM"

  env -u GOROOT -u GOTOOLDIR \
    LITELLM_PROVIDER_FIXTURE="$fixture" \
    go test -C "$fork" ./... >/dev/null \
    || fail "S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented"

  printf '%s\n' "S04 PASS: importer, optional team compatibility, metadata parity, and stable read-back proven offline"
}

check_s05() {
  local production="$REPO_ROOT/components/litellm/environments/home/production/terragrunt.hcl"
  local manifest="$REPO_ROOT/components/litellm/environments/home/production/models.json"
  local exceptions="$REPO_ROOT/components/litellm/environments/home/production/manual-exceptions.json"
  local variables="$REPO_ROOT/components/litellm/modules/model/variables.tf"
  local main="$REPO_ROOT/components/litellm/modules/model/main.tf"
  local aliases="$SCRIPT_DIR/fixtures/litellm-discovery-aliases.json"
  local allowlists="$SCRIPT_DIR/fixtures/litellm-discovery-allowlists.json"
  local catalog="$REPO_ROOT/catalogs/opencode-zen.json"
  local production_render="$TEST_TMP/litellm-production-render.json"
  local canary_render="$TEST_TMP/litellm-canary-s05-render.json"
  local field mode production_key canary_key

  [[ -f "$production" && -f "$manifest" ]] \
    || fail "S05 RED: Discovery production model manifest not implemented"

  [[ -f "$aliases" && -f "$allowlists" ]] \
    || fail "S05 RED: Discovery alias or allowlist fixture missing"

  jq -e '
    type == "array" and
    length == 12 and
    (unique | length) == 12 and
    . == (sort)
  ' "$aliases" >/dev/null \
    || fail "S05 RED: Discovery alias fixture must contain exactly 12 unique sorted aliases"

  jq -e '
    . as $aliases |
    [
      "bge-m3",
      "bge-reranker-v2-m3",
      "faster-whisper-pt-br",
      "faster-whisper-turbo-pt-br",
      "parakeet-pt-br",
      "tagarela-pt-br",
      "tts-pt-br",
      "tts-pt-br-piper"
    ] as $retired |
    all($retired[]; . as $alias | $aliases | index($alias) == null)
  ' "$aliases" >/dev/null \
    || fail "S05 RED: retired Kepler aliases remain declared"

  jq -e --slurpfile aliases "$aliases" '
    (.models | type == "object") and
    ((.models | keys) == $aliases[0]) and
    ([.models[].mode] | unique) == ["audio_transcription", "chat"] and
    ([.models[] | select(.model_api_base | test("kepler"; "i"))] | map(.mode) | sort | unique) == ["audio_transcription", "chat"] and
    ([.models[] | select((.context_limit // null) == null)] | length) > 0 and
    ([.models[] | select((.output_limit // null) == null)] | length) > 0 and
    (all(.models[];
      (.model_api_key | type == "string") and
      (.model_api_key == "sk-no-key-required" or
       (.model_api_key | test("^os\\.environ/[A-Z][A-Z0-9_]*$")))))
  ' "$manifest" >/dev/null \
    || fail "S05 RED: Discovery manifest aliases, modes, optional limits, or API-key references are invalid"

  jq -e --slurpfile catalog "$catalog" '
    .models as $models |
    [
      {alias: "glm-5", source_id: "glm-5.2"},
      {alias: "kimi-k2-code", source_id: "kimi-k2.7-code"},
      {alias: "minimax-m2", source_id: "minimax-m2.7"},
      {alias: "zen-free", source_id: "deepseek-v4-flash-free"},
      {alias: "zen-free-pickle", source_id: "big-pickle"}
    ] |
    all(.[];
      . as $route |
      (first($catalog[0].models[] | select(.source_id == $route.source_id))) as $benchmark |
      ($models[$route.alias].context_limit == $benchmark.context_limit) and
      ($models[$route.alias].output_limit == $benchmark.output_limit) and
      ($models[$route.alias].input_cost_per_million_tokens == $benchmark.input_price_per_million) and
      ($models[$route.alias].output_cost_per_million_tokens == $benchmark.output_price_per_million))
  ' "$manifest" >/dev/null \
    || fail "S05 RED: reviewed Zen routes diverge from the normalized context or pricing benchmark"

  for mode in completion embedding image_generation chat moderation audio_transcription audio_speech rerank; do
    assert_file_contains "$variables" "\"${mode}\"" \
      "S05 RED: model module does not accept provider mode ${mode}"
  done
  assert_file_contains "$variables" 'context_limit[[:space:]]*=[[:space:]]*optional\(number' \
    "S05 RED: context_limit is not optional/null-capable"
  assert_file_contains "$variables" 'output_limit[[:space:]]*=[[:space:]]*optional\(number' \
    "S05 RED: output_limit is not optional/null-capable"
  assert_file_contains "$variables" 'output_limit[^\n]*>=[[:space:]]*0' \
    "S05 RED: output_limit does not permit zero"
  assert_file_contains "$variables" '"pdf"' \
    "S05 RED: pdf is not an accepted model modality"

  for field in probe_skip max_tokens; do
    jq -e --arg field "$field" \
      '[.models[] | select(has($field))] | length > 0' "$manifest" >/dev/null \
      || fail "S05 RED: Discovery manifest does not preserve ${field}"
  done
  for field in supports_vision input_cost_per_character default_voice probe_language probe_text probe_skip max_tokens; do
    assert_file_contains "$main" "${field}[[:space:]]*=[[:space:]]*each\\.value\\.${field}" \
      "S05 RED: model module does not directly map ${field}"
  done
  assert_file_contains "$variables" 'input_cost_per_second[[:space:]]*=[[:space:]]*optional\(number' \
    "S05 RED: input_cost_per_second is not a typed module input"
  assert_file_contains "$main" 'input_cost_per_second[[:space:]]*=[[:space:]]*each\.value\.input_cost_per_second' \
    "S05 RED: model module does not directly map input_cost_per_second"
  assert_file_excludes "$main" 'additional_litellm_params[[:space:]]*=[[:space:]]*merge\(' \
    "S05 RED: typed metadata is tunneled through additional_litellm_params"

  [[ -f "$exceptions" ]] \
    || fail "S05 RED: reviewed manual route exception catalog missing"
  jq -e '
    (keys | sort) == (["mimo", "mimo-pro", "qwen3-max"] | sort) and
    all(.[];
      (.reason | type == "string" and length > 0) and
      (.reviewed_on | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")))
  ' "$exceptions" >/dev/null \
    || fail "S05 RED: manual exceptions must be exact, reasoned, and review-dated"

  jq -e --slurpfile aliases "$aliases" '
    (keys == ["hermes"]) and
    ([to_entries[].value[]] |
      all(.[]; . as $alias | $aliases[0] | index($alias) != null))
  ' "$allowlists" >/dev/null \
    || fail "S05 RED: consumer allowlists retain retired consumers or undeclared aliases"

  assert_file_contains "$variables" 'variable[[:space:]]+"yaml_model_list_cutoff"' \
    "S05 RED: explicit legacy YAML cutoff marker missing"
  assert_file_contains "$variables" 'default[[:space:]]*=[[:space:]]*false' \
    "S05 RED: legacy YAML cutoff marker must default false"

  UNIFI_STATE_PASSPHRASE='contract-dummy-value' \
    terragrunt render --json --non-interactive --no-color \
      --working-dir "$(dirname "$production")" >"$production_render"
  UNIFI_STATE_PASSPHRASE='contract-dummy-value' \
    terragrunt render --json --non-interactive --no-color \
      --working-dir "$REPO_ROOT/components/litellm/environments/home/canary" >"$canary_render"
  production_key=$(jq -r '.remote_state.config.key' "$production_render")
  canary_key=$(jq -r '.remote_state.config.key' "$canary_render")
  [[ -n "$production_key" && -n "$canary_key" && "$production_key" != "$canary_key" ]] \
    || fail "S05 RED: production and canary units share a state key"

  printf '%s\n' "S05 PASS: exact Discovery production manifest, Kepler retirement, allowlists, and cutoff guard proven offline"
}

case "$1" in
  s01) check_s01 ;;
  s02) check_s02 ;;
  s03) check_s03 ;;
  s04) check_s04 ;;
  s05) check_s05 ;;
  all) check_s01 && check_s02 && check_s03 && check_s04 && check_s05 ;;
  *)
    printf '%s\n' "usage: tests/infra-ssot-contract.sh {s01|s02|s03|s04|s05|all}" >&2
    exit 64
    ;;
esac
