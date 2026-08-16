#!/usr/bin/env bats

@test "drift check exposes the state key to dependency tofu commands" {
  run grep -F 'export TF_VAR_state_passphrase="${TF_VAR_state_passphrase:-${UNIFI_STATE_PASSPHRASE:-}}"' bin/drift-check.sh

  [ "$status" -eq 0 ]
}

@test "drift check executes its pinned working tree without git refresh" {
  run grep -E 'git (pull|fetch|clone)' bin/drift-check.sh

  [ "$status" -eq 1 ]
}

@test "drift check excludes the disposable LiteLLM lifecycle canary" {
  run grep -F -- "--filter '!components/litellm/environments/home/canary'" bin/drift-check.sh

  [ "$status" -eq 0 ]
}

@test "drift alert includes bounded plan evidence for Cleytin" {
  run grep -F -- "grep -am 40 -E 'Plan:|will be (updated|created|destroyed)|# '" bin/drift-check.sh
  [ "$status" -eq 0 ]

  run grep -F -- 'summary="${summary:0:1500}"' bin/drift-check.sh
  [ "$status" -eq 0 ]

  run grep -F -- '--arg summary "$summary"' bin/drift-check.sh
  [ "$status" -eq 0 ]

  run grep -F -- '"\n\n"+$summary' bin/drift-check.sh
  [ "$status" -eq 0 ]
}
