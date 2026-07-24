#!/usr/bin/env bats

@test "LiteLLM provider mints the HA harness key" {
  ! grep -q 'key *= *var\.key' components/litellm/modules/key/main.tf
  ! grep -q 'variable "key"' components/litellm/modules/key/variables.tf
  grep -q 'resource "litellm_key" "rotation"' components/litellm/modules/key/main.tf
  grep -Fq 'ignore_changes = [key]' components/litellm/modules/key/main.tf
  grep -q 'value *= *litellm_key\.rotation\.key' components/litellm/modules/key/outputs.tf
  grep -q 'sensitive *= *true' components/litellm/modules/key/outputs.tf
}

@test "OpenBao handoff owns only the LiteLLM key path" {
  grep -q 'dependency "ha_harness_key"' components/openbao/environments/home/ha-harness-litellm/terragrunt.hcl
  grep -Fq 'name    = "home/ha-harness-litellm"' components/openbao/environments/home/ha-harness-litellm/terragrunt.hcl
  ! grep -R -q 'HA_HARNESS_TOKEN' components/openbao
}
