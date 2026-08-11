# NetBird retirement; Pangolin deferred

**Status:** NetBird retired 2026-08-10; Pangolin remains a separate evaluation

## Decision

- Keep Tailscale as the fleet administration, service-routing, and break-glass
  overlay.
- Retire NetBird and its dedicated PocketID instance completely. Do not replace
  it with another self-hosted control plane.
- Evaluate Pangolin independently. It is not a prerequisite or rollback path for
  this retirement.

## Retirement evidence

- `desktop-nixos`: clients, Discovery control plane, Voyager/Vanguard relays,
  secrets, fleet facts, tests, and obsolete docs removed. Endeavour, Discovery,
  Voyager, and Vanguard were activated and verified absent. Kepler has the
  removal generation staged but remained unreachable after reboot, NanoKVM
  checks, and Wake-on-LAN; verify it after physical recovery. Laptop is offline
  and must activate the current source when it next returns.
- `servarr`: SWAG routes, relay monitoring, database provisioning, and NetBird
  environment names removed. Buzz now uses Tailscale. Discovery and Kepler
  stacks were recreated from the replacement source.
- `homelab-iac`: provider components and remote state ownership removed; relay
  DNS deleted; OCI TCP/UDP 443 ingress closed; Tailscale ACL entries removed;
  local provider credentials deleted. The standalone provider repository was
  archived and detached from Terraform ownership.
- Recovery: PocketID restored healthy in a networkless Orion drill. A fresh full
  PostgreSQL dump restored into an isolated PostgreSQL 18 container and included
  the NetBird database (39 tables, 28 representative rows).
- Destructive cleanup: the live NetBird database and role, PocketID bind data,
  containers, images, rendered files, and all Vault KV versions were deleted.
  Encrypted/versioned infrastructure state and the dated Orion/Restic backups
  remain as recovery evidence.

## Remaining gate

Recover Kepler physically, confirm it booted the staged generation, and run the
standard absence check. When the offline laptop returns, switch it to current
`desktop-nixos` and run the same check. No NetBird service should be restored.

## Pangolin boundary

If application access beyond Tailscale is still needed, evaluate Pangolin Cloud
with two outbound Newt connectors. Require LTE/restrictive-Wi-Fi access,
single-site failure, recovery, alert delivery, and soak evidence before calling
it production. Keep that work separate from this completed retirement.
