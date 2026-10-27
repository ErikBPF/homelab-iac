#!/usr/bin/env bats

@test "household HA routes use qwen-chat and qwen-pqnld while the 4B route stays withdrawn" {
  jq -e '
    (.models | has("ha-agent-qwen4b") | not) and
    (.models["qwen-chat"].mode == "chat") and
    (.models["qwen-chat"].model_api_base | length > 0) and
    (.models["qwen-pqnld"].mode == "chat") and
    (.models["qwen-pqnld"].model_api_base == "http://100.77.14.27:11560/v1")
  ' components/litellm/environments/home/production/models.json
  test -f components/litellm/environments/home/ha-harness-key/terragrunt.hcl
  test -f components/openbao/environments/home/ha-harness-litellm/terragrunt.hcl
}
