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

  grep -Fq 'models                = ["bge-m3", "bge-reranker-v2-m3", "qwen-chat"]' "$key_unit"
  grep -Fq 'consumer = "cognee"' "$key_unit"
  grep -Fq 'dependency "cognee_key"' "$vault_unit"
  grep -Fq 'name          = "lab/cognee-litellm"' "$vault_unit"
  grep -Fq 'LLM_API_KEY = dependency.cognee_key.outputs.key' "$vault_unit"
}
