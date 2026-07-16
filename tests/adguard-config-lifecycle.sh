#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$root/tests/fixtures/adguard-config
image=adguard/adguardhome:v0.108.0-b.83
runtime=
for candidate in docker podman; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" info >/dev/null 2>&1; then runtime=$candidate; break; fi
done
test -n "$runtime" || { echo 'RED: no local container runtime' >&2; exit 1; }

tmp=$(mktemp -d); name=adguard-config-lifecycle-$$; port=$((31000 + $$ % 20000))
cleanup() { "$runtime" rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap cleanup EXIT INT TERM
mkdir -p "$tmp/conf" "$tmp/work" "$tmp/tofu"
cp "$fixture/AdGuardHome.yaml" "$tmp/conf/AdGuardHome.yaml"
cp "$fixture/main.tf" "$tmp/tofu/main.tf"

if ! "$runtime" image inspect "$image" >/dev/null 2>&1; then "$runtime" pull "$image" >/dev/null; fi
"$runtime" run -d --name "$name" -p "127.0.0.1:$port:3000" \
  -v "$tmp/conf:/opt/adguardhome/conf" -v "$tmp/work:/opt/adguardhome/work" "$image" >/dev/null
for _ in $(seq 1 60); do curl -fsS "http://127.0.0.1:$port/control/status" >/dev/null 2>&1 && break; sleep 1; done
curl -fsS "http://127.0.0.1:$port/control/status" >/dev/null 2>&1 || { echo 'RED: local AdGuard did not start' >&2; exit 1; }

export TF_IN_AUTOMATION=1 TF_INPUT=0
run_phase() { local phase=$1 rc; shift; tofu -chdir="$tmp/tofu" "$@" >"$tmp/tofu.log" 2>&1 || { rc=$?; echo "RED: provider lifecycle failed at $phase (rc=$rc)" >&2; exit 1; }; }
run_refresh() {
  local phase=$1 cache=$2 rc; shift 2
  local plan=$tmp/$phase.tfplan
  if tofu -chdir="$tmp/tofu" plan -detailed-exitcode -out="$plan" \
      -var="host=127.0.0.1:$port" -var="cache_size=$cache" >"$tmp/tofu.log" 2>&1; then return 0; else rc=$?; fi
  if test "$rc" -eq 2; then
    tofu -chdir="$tmp/tofu" show -json >"$tmp/state.json"
    tofu -chdir="$tmp/tofu" show -json "$plan" >"$tmp/plan.json"
    jq -r '.resource_changes[] | "DRIFT-ACTION: " + (.change.actions|join(","))' "$tmp/plan.json"
    jq -nr --slurpfile state "$tmp/state.json" --slurpfile plan "$tmp/plan.json" '
      def leaves: [paths(scalars)];
      ($state[0].values.root_module.resources[0].values) as $before |
      ($plan[0].planned_values.root_module.resources[0].values) as $after |
      (($before|leaves)+($after|leaves)|unique[]) as $path |
      select(($before|getpath($path)) != ($after|getpath($path))) |
      "DRIFT-FIELD: " + ($path|map(tostring)|join("."))'
  fi
  echo "RED: provider lifecycle failed at $phase (rc=$rc)" >&2; exit 1
}
run_phase init init -backend=false
if test -n "${ADGUARD_PROVIDER_DEV_BINARY:-}"; then
  test -x "$ADGUARD_PROVIDER_DEV_BINARY" || { echo 'RED: provider dev binary is not executable' >&2; exit 1; }
  mkdir "$tmp/provider-dev"
  ln -s "$ADGUARD_PROVIDER_DEV_BINARY" "$tmp/provider-dev/terraform-provider-adguard"
  cat >"$tmp/tofu.rc" <<EOF
provider_installation {
  dev_overrides {
    "gmichels/adguard" = "$tmp/provider-dev"
  }
  direct {}
}
EOF
  export TF_CLI_CONFIG_FILE="$tmp/tofu.rc"
fi
run_phase validate validate
run_phase create apply -auto-approve -var="host=127.0.0.1:$port" -var=cache_size=1024
run_refresh refresh-initial 1024
run_phase update apply -auto-approve -var="host=127.0.0.1:$port" -var=cache_size=2048
run_refresh refresh-updated 2048
run_phase delete destroy -auto-approve -var="host=127.0.0.1:$port" -var=cache_size=2048
echo 'PASS: disposable disabled-DHCP lifecycle'
