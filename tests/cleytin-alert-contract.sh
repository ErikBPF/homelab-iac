#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
id=1532710143517659356

files=(
  references/repos/desktop-nixos/modules/hosts/discovery/_kindle-release-agent.py
  references/repos/desktop-nixos/modules/hosts/discovery/vault.nix
  references/repos/desktop-nixos/modules/services/dead-mans-switch.nix
  references/repos/desktop-nixos/modules/services/restic-tofu-state.nix
  references/repos/desktop-nixos/modules/services/swag-cert-monitor.nix
  references/repos/homelab-iac/bin/drift-check.sh
  references/repos/homelab-gitops/platform/monitoring/files/alerting/templates.yaml
  references/repos/servarr/machines/discovery/scripts/litellm-validate-cron.sh
  references/repos/servarr/machines/discovery/scripts/pricing-drift-cron.sh
)

for file in "${files[@]}"; do
  grep -Fqs "$id" "$root/$file" || {
    echo "$file: alert does not address Cleytin" >&2
    exit 1
  }
done

for file in "${files[@]}"; do
  [[ "$file" == *templates.yaml ]] && continue
  grep -Fqs 'allowed_mentions' "$root/$file" || {
    echo "$file: Cleytin mention is not explicitly allowed" >&2
    exit 1
  }
done
