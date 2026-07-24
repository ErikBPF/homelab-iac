#!/usr/bin/env bats

@test "LiteLLM provider mints the HA harness key" {
  ! grep -q 'key *= *var\.key' components/litellm/modules/key/main.tf
  ! grep -q 'variable "key"' components/litellm/modules/key/variables.tf
  grep -q 'value *= *litellm_key\.this\.key' components/litellm/modules/key/outputs.tf
  grep -q 'sensitive *= *true' components/litellm/modules/key/outputs.tf
}
