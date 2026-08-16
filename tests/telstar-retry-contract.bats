#!/usr/bin/env bats

@test "state-lock acquisition failure has a non-retry exit" {
  script=oracle/bin/telstar-get-retry.sh
  grep -Fq 'Error acquiring the state lock' "$script"
  grep -Fq 'exit 75' "$script"
}

@test "lock recovery validates identity age and active writers" {
  script=oracle/bin/telstar-lock-recover.sh
  test -x "$script"
  grep -Fq 'pgrep -f' "$script"
  grep -Fq 'Error acquiring the state lock' "$script"
  grep -Fq 'ID:' "$script"
  grep -Fq 'Created:' "$script"
  grep -Fq 'tofu-state/oracle/compute-telstar/terraform.tfstate' "$script"
  grep -Fq '240' "$script"
  grep -Fq 'force-unlock -force' "$script"
}
