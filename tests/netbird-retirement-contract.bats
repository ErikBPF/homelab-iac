#!/usr/bin/env bats

@test "NetBird and its dedicated PocketID client IaC are retired" {
  [ ! -e netbird ]
  [ ! -e pocketid ]
  ! grep -F 'netbird/' tests/fixtures/state-keys.txt
  ! grep -F 'pocketid/clients' tests/fixtures/state-keys.txt
}

@test "NetBird public edge is removed without reopening bootstrap SSH" {
  run rg -i 'netbird' README.md bin cloudflare github oracle tailscale/acl/policy.hujson \
    -g '!**/.terragrunt-cache/**'
  [ "$status" -eq 1 ]
  ! grep -F '"relay.pastelariadev.com"' cloudflare/dns/terragrunt.hcl
  ! grep -F '"relay2.pastelariadev.com"' cloudflare/dns/terragrunt.hcl
  grep -F 'bootstrap_ssh_enabled = false' oracle/compute/terragrunt.hcl
  grep -F 'for_each = var.bootstrap_ssh_enabled ? [1] : []' oracle/modules/instance/main.tf
}

@test "NetBird-only contracts are removed" {
  [ ! -e tests/netbird-buzz-access-contract.bats ]
  [ ! -e tests/netbird-route-access-contract.bats ]
}
