#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export NO_PROXY='*'
  export HTTPS_PROXY='http://127.0.0.1:9'
  export HTTP_PROXY='http://127.0.0.1:9'
}

@test "S01 shared-root canary contract" {
  run "$REPO_ROOT/tests/infra-ssot-contract.sh" s01
  printf '%s\n' "$output"
  [ "$status" -eq 0 ]
}

@test "S02 LiteLLM provider canary contract" {
  run "$REPO_ROOT/tests/infra-ssot-contract.sh" s02
  printf '%s\n' "$output"
  [ "$status" -eq 0 ]
}

@test "S03 catalog and dependency automation contract" {
  run "$REPO_ROOT/tests/infra-ssot-contract.sh" s03
  printf '%s\n' "$output"
  [ "$status" -eq 0 ]
}

@test "S04 LiteLLM provider lifecycle and metadata contract" {
  run "$REPO_ROOT/tests/infra-ssot-contract.sh" s04
  printf '%s\n' "$output"
  [ "$status" -eq 0 ]
}

@test "S05 Discovery production model manifest contract" {
  run "$REPO_ROOT/tests/infra-ssot-contract.sh" s05
  printf '%s\n' "$output"
  [ "$status" -eq 0 ]
}
