#!/usr/bin/env bats

@test "Trivy blocks high and critical IaC findings from a pinned action" {
  workflow="$BATS_TEST_DIRNAME/../.github/workflows/ci.yml"

  grep -Fq \
    "aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25" \
    "$workflow"
  grep -Fq "scan-type: config" "$workflow"
  grep -Fq "skip-dirs: '**/.terragrunt-cache'" "$workflow"
  grep -Fq "severity: HIGH,CRITICAL" "$workflow"
  grep -Fq 'exit-code: "1"' "$workflow"
}
