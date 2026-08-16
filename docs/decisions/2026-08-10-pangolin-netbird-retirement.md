# NetBird retirement; Pangolin deferred

**Status:** NetBird retired 2026-08-10; Pangolin two-site pilot live, acceptance
pending

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
  Voyager, Vanguard, and Kepler were activated and verified absent. Laptop is
  offline and must activate the current source when it next returns.
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

When the offline laptop returns, switch it to current `desktop-nixos` and run
the same absence check. No NetBird service should be restored.

## Pangolin boundary

The independent Pangolin Cloud pilot was deployed 2026-08-11 with two outbound
Newt sites (`home-discovery` and `home-kepler`). A user-bound private wildcard
resource sends only TCP/443 for `*.homelab.pastelariadev.com` to Discovery's
SWAG ingress. Bootstrap credentials live in Sops; Newt persists rotated site
credentials locally. Metrics stay loopback-only and feed the existing Alloy
pipeline.

Both sites passed service, persisted-credential, connector-health, metrics, TLS,
and SWAG/Grafana database checks. NetBird units, processes, containers, and live
state are absent on Discovery and Kepler. Keep Tailscale as administration and
break-glass access.

Do not call Pangolin production until a real Pangolin client passes LTE and
restrictive-Wi-Fi access, each single-site failure and recovery is exercised,
the redundancy alert is delivered, and a seven-day soak completes.
