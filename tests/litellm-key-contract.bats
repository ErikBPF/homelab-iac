#!/usr/bin/env bats

@test "LiteLLM provider mints the HA harness key" {
  ! grep -q 'key *= *var\.key' components/litellm/modules/key/main.tf
  ! grep -q 'variable "key"' components/litellm/modules/key/variables.tf
  grep -q 'resource "litellm_key" "rotation"' components/litellm/modules/key/main.tf
  grep -Fq 'ignore_changes = all' components/litellm/modules/key/main.tf
  grep -q 'value *= *litellm_key\.rotation\.generated_key' components/litellm/modules/key/outputs.tf
  grep -Fq 'version = "1.2.0"' components/litellm/modules/key/versions.tf
  grep -q 'sensitive *= *true' components/litellm/modules/key/outputs.tf
}

@test "OpenBao handoff owns only the LiteLLM key path" {
  grep -q 'dependency "ha_harness_key"' components/openbao/environments/home/ha-harness-litellm/terragrunt.hcl
  grep -Eq 'name[[:space:]]*=[[:space:]]*"home/ha-harness-litellm"' components/openbao/environments/home/ha-harness-litellm/terragrunt.hcl
  grep -q 'variable "write_version"' components/openbao/modules/kv-secret/variables.tf
  ! grep -q 'variable "version"' components/openbao/modules/kv-secret/variables.tf
  ! grep -R -q 'HA_HARNESS_TOKEN' components/openbao
  grep -q 'skip_child_token *= *true' components/openbao/root.hcl
}

@test "Cognee gets a local-only LiteLLM key through OpenBao" {
  key_unit=components/litellm/environments/home/cognee-key/terragrunt.hcl
  vault_unit=components/openbao/environments/home/cognee-litellm/terragrunt.hcl
  policy=components/openbao/modules/runtime-secret-foundation/main.tf

  grep -Fq 'models                = ["bge-m3", "bge-reranker-v2-m3", "qwen-chat"]' "$key_unit"
  grep -Fq 'consumer = "cognee"' "$key_unit"
  grep -Fq 'dependency "cognee_key"' "$vault_unit"
  grep -Fq 'name          = "lab/cognee-litellm"' "$vault_unit"
  grep -Fq 'LLM_API_KEY = dependency.cognee_key.outputs.key' "$vault_unit"
  grep -Fq 'path \"secret/data/lab/cognee-litellm\" { capabilities = [\"create\", \"update\", \"read\"] }' "$policy"
  grep -Fq 'path \"secret/metadata/lab/cognee-litellm\" { capabilities = [\"read\"] }' "$policy"
}

@test "DeepSeek Harness gets a scoped 25 USD LiteLLM key through OpenBao" {
  key_unit=components/litellm/environments/home/deepseek-harness-key/terragrunt.hcl
  vault_unit=components/openbao/environments/home/deepseek-harness-litellm/terragrunt.hcl
  vault_foundation=components/openbao/modules/runtime-secret-foundation/main.tf

  grep -Eq 'max_budget[[:space:]]*=[[:space:]]*25' "$key_unit"
  grep -Eq 'budget_duration[[:space:]]*=[[:space:]]*"30d"' "$key_unit"
  grep -Eq 'models[[:space:]]*=[[:space:]]*\["deepseek-v4-flash", "deepseek-v4-pro", "qwen-chat"\]' "$key_unit"
  grep -Eq 'key_alias[[:space:]]*=[[:space:]]*"svc-homelab-iac-deepseek-harness-model-inference"' "$key_unit"
  grep -Eq 'consumer[[:space:]]*=[[:space:]]*"deepseek-harness"' "$key_unit"
  grep -Fq 'modules//scoped-key' "$key_unit"
  [ "$(grep -c '^resource "litellm_key"' components/litellm/modules/scoped-key/main.tf)" -eq 1 ]
  grep -Eq 'max_budget[[:space:]]*=[[:space:]]*var.max_budget' components/litellm/modules/scoped-key/main.tf
  grep -Eq 'budget_duration[[:space:]]*=[[:space:]]*var.budget_duration' components/litellm/modules/scoped-key/main.tf
  grep -Fq 'dependency "deepseek_harness_key"' "$vault_unit"
  grep -Fq 'name          = "home/deepseek-harness-litellm"' "$vault_unit"
  grep -Fq 'LITELLM_HOMELAB_API_KEY = dependency.deepseek_harness_key.outputs.key' "$vault_unit"
  grep -Fq 'path \"secret/data/home/deepseek-harness-litellm\"' "$vault_foundation"
  grep -Fq 'path \"secret/metadata/home/deepseek-harness-litellm\"' "$vault_foundation"

  jq -e --slurpfile catalog catalogs/opencode-zen.json '
    .models["deepseek-v4-pro"] as $route |
    first($catalog[0].models[] | select(.source_id == "deepseek-v4-pro")) as $source |
    ($route.base_model == $source.source_id) and
    ($route.context_limit == $source.context_limit) and
    ($route.output_limit == $source.output_limit) and
    ($route.input_cost_per_million_tokens == $source.input_price_per_million) and
    ($route.output_cost_per_million_tokens == $source.output_price_per_million)
  ' components/litellm/environments/home/production/models.json
}
