#!/usr/bin/env bats

@test "paused household HA route is withdrawn while the chat canary remains promised" {
  jq -e '
    (.models | has("ha-agent-qwen4b") | not) and
    (.models["qwen-chat"].mode == "chat") and
    (.models["qwen-chat"].model_api_base | length > 0)
  ' components/litellm/environments/home/production/models.json
  test -f components/litellm/environments/home/ha-harness-key/terragrunt.hcl
  test -f components/openbao/environments/home/ha-harness-litellm/terragrunt.hcl
}
