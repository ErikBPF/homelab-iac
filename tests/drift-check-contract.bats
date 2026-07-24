#!/usr/bin/env bats

@test "drift check exposes the state key to dependency tofu commands" {
  run grep -F 'export TF_VAR_state_passphrase="${TF_VAR_state_passphrase:-${UNIFI_STATE_PASSPHRASE:-}}"' bin/drift-check.sh

  [ "$status" -eq 0 ]
}

@test "drift check excludes the disposable LiteLLM lifecycle canary" {
  run grep -F -- "--filter '!components/litellm/environments/home/canary'" bin/drift-check.sh

  [ "$status" -eq 0 ]
}
