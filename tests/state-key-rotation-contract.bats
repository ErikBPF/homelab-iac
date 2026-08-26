#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(CDPATH= cd -- "$BATS_TEST_DIRNAME/.." && pwd)
}

@test "every state root uses the rotated provider identity without fallback keys" {
  for root in _shared cloudflare github oracle tailscale unifi; do
    config="$REPO_ROOT/$root/root.hcl"
    grep -Fq 'key_provider "pbkdf2" "current"' "$config"
    grep -Fq 'method "aes_gcm" "current"' "$config"
    ! grep -Fq 'state_passphrase_previous' "$config"
    ! grep -Fq 'fallback {' "$config"
  done
}
