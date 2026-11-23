#!/usr/bin/env bats

@test "household HA routes use qwen-chat, qwen-pqnld, and the 4B tool route" {
  jq -e '
    (.models["ha-agent-qwen4b"].mode == "chat") and
    (.models["ha-agent-qwen4b"].model_api_base == "http://100.90.113.117:8088/v1") and
    (.models["qwen-chat"].mode == "chat") and
    (.models["qwen-chat"].model_api_base | length > 0) and
    (.models["qwen-pqnld"].mode == "chat") and
    (.models["qwen-pqnld"].model_api_base == "http://100.77.14.27:11560/v1")
  ' components/litellm/environments/home/production/models.json
  test -f components/litellm/environments/home/ha-harness-key/terragrunt.hcl
  test -f components/openbao/environments/home/ha-harness-litellm/terragrunt.hcl
}
