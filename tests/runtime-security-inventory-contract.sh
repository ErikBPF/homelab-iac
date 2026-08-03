#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inventory="$root/docs/runtime-security-inventory.json"
fleet="$root/references/repos/desktop-nixos/fleet.json"

jq -e '
  .schemaVersion == 1
  and (.addressSets | type == "object")
  and (.hosts | type == "object")
  and all(.addressSets[];
    (.cidrs | type == "array" and length > 0)
    and all(.cidrs[]; test("^([0-9a-fA-F:.]+)/(0|[1-9][0-9]{0,2})$"))
  )
  and (.addressSets["ssh-login-whitelist"].members
    | sort == ["discovery", "endeavour", "gemini"])
  and (.addressSets["ssh-login-whitelist"].cidrs
    | contains(["192.168.10.200/32", "192.168.10.205/32"]))
  and all(.hosts[];
    (.trustZone | IN("home", "public", "roaming", "appliance"))
    and (.sshExposure | IN("none", "overlay", "lan-overlay", "public"))
    and (.criticality | IN("critical", "standard"))
    and (.monitoringOwner | type == "string" and length > 0)
    and (.sshAlarmReadiness | IN("ready", "blocked", "not-applicable"))
    and (
      if .sshAlarmReadiness == "ready"
      then (
        (.expectedSshSourceSets | type == "array" and length > 0)
      )
      elif .sshAlarmReadiness == "blocked"
      then (.blocker | type == "string" and length > 0)
      else .sshExposure == "none"
      end
    )
  )
  and all(.hosts[];
    if .trustZone == "public" and .sshAlarmReadiness == "ready"
    then (.expectedSshSourceSets == ["ssh-login-whitelist"])
    else true
    end
  )
  and all(.hosts | to_entries[];
    if (.key == "vanguard" or .key == "voyager")
    then (
      .value.sshAlarmReadiness == "ready"
      and .value.sshExposure == "overlay"
      and .value.expectedSshSourceSets == ["ssh-login-whitelist"]
    )
    else true
    end
  )
' "$inventory" >/dev/null

jq -n \
  --slurpfile fleet "$fleet" \
  --slurpfile inventory "$inventory" \
  '($fleet[0].hosts | keys) == ($inventory[0].hosts | keys)' \
  | grep -qx true

jq -e '
  . as $inventory
  | all(.hosts[];
      all(.expectedSshSourceSets[]?;
        . as $name | $inventory.addressSets | has($name)
      )
    )
' "$inventory" >/dev/null

if grep -Eqi 'discord(app)?[_-]?(webhook|token)|https://discord(app)?\.com/api/webhooks|private[_-]?key' "$inventory"; then
  echo "runtime security inventory contains secret-shaped data" >&2
  exit 1
fi

echo "runtime security inventory OK"
