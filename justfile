set shell := ["bash", "-euo", "pipefail", "-c"]

status:
    bin/homelab status

audit:
    bin/homelab audit

docs-check:
    bin/homelab docs-check

fleet-drift:
    bin/homelab fleet-drift

fleet-update:
    bin/homelab fleet-update

test:
    bash tests/contracts.sh
