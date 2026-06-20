# module: wlan

Wraps `unifi_wlan` (SSIDs). Skeleton — `variables.tf` / `main.tf` / `outputs.tf`
are generated during Phase-1 import (`tofu plan -generate-config-out`), then
refactored to match the `../network` pattern (typed input map -> `for_each`).
