# OpenTofu 1.12 cannot override computed nested devices blocks. The mock's
# empty list exercises native missing-device rejection. Seven production-HCL
# expression fixtures cover identity fields in tests/tailscale-identity-guard.py.
mock_provider "tailscale" {}

variables {
  acl = "{}"
}

run "missing_discovery_blocks_approval" {
  command = plan

  expect_failures = [tailscale_device_subnet_routes.discovery]
}
