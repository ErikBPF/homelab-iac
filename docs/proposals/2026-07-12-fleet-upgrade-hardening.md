# Fleet upgrade contract

**Status:** Partially implemented — build distribution and the 2026-07-14
rollout are verified; upgrade orchestration and capacity/evidence automation
remain open.

## Purpose

Give a fresh operator one safe path for flake-input upgrades. The contract is
impact-scoped: fleet-wide gates apply to inputs that affect shared system
closures; leaf inputs apply only to their consumer hosts.

## Already implemented

- NetBird management renders raw sops values and refuses empty secrets.
- Node exporter and Alloy expose failed-systemd-unit metrics; Grafana owns the
  Discord-routed alert.
- Future disko installs use a 2G ESP.
- `fleet-status` exposes booted-versus-target nixpkgs drift.
- systemd-boot boot counting guards boot viability; unattended upgrades check
  critical units and gateway reachability.
- Frozen-PID1 recovery is documented.

These are as-built prerequisites, not work items in this RFC.

## Implementation checkpoint — 2026-07-14

The build path now has explicit, independently verifiable operations:

- `build` realizes a host closure without activation; `switch` is the explicit
  local activation command.
- Orion is the primary x86 builder. Kepler is a constrained spillover builder;
  target-aware selection prevents a host from recursively building through
  itself.
- `builder-preflight` checks each configured SSH Nix store, including its
  explicit port and builder key, without realizing a production closure.
- `build-all` submits the fleet as one scheduler graph so shared derivations are
  built once and independent work can run concurrently.
- `check-remote orion [ref]` runs evaluation and checks from a temporary clean
  clone of a commit already published on `origin/main`; Orion builds locally
  and may spill work to Kepler. `check-remote kepler [ref]` reverses those roles.
  The dispatching laptop performs no evaluation or build.
- Remote fleet checks exclude Endeavour so the proprietary KACE fixed-output
  never enters Orion or Kepler's stores. Endeavour has a separate dispatched
  check and remains the only host that imports or installs KACE.
- The K3s HA fixture follows the production control-plane bootstrap invariant
  instead of racing three embedded-etcd members at once.

Fresh verification used both Orion and Kepler during the full flake check. The
K3s HA test completed in 551.78 seconds. Laptop, Discovery, Pathfinder, Orion,
Kepler, and Voyager report the target nixpkgs revision. Voyager's offsite
receiver was recreated from the published Servarr revision and reports healthy.
Archinaut was unreachable and remains an explicit manual-window exclusion;
Telstar and Vanguard lack fleet-status tailnet addresses.

This checkpoint proves the build substrate and one rollout. It does not claim
that the full candidate/soak/capacity/alert contract below is automated.

## Candidate gate

Routine revisions soak for **72 hours** after upstream publication. A
security-critical update may bypass soak, but no build, capacity, rollout, or
verification gate.

Before rollout:

1. Refuse to run if `flake.lock` is already dirty.
2. Preserve the exact lock file in a temporary file, update, and restore it via
   a trap on failure. Never use `git checkout flake.lock`.
3. Run the full repository checks and build every affected host closure on
   Orion before Orion is rebooted.
4. Require every host in rollout scope to report its current revision and
   preflight health. Record intentional exclusions and their catch-up window.
5. Run the ESP capacity contract below.
6. Require a successful synthetic failed-unit alert drill within the previous
   90 days.

## ESP capacity contract

Before activation, `/boot` must fit:

- the candidate kernel and initrd;
- one known-good kernel and initrd; and
- 25% reserve after both generations are installed.

Projected reserve below 50% warns. Projected reserve below 25% blocks
activation and schedules the host's ESP migration. Cleanup may restore current
host safety, but never waives the capacity requirement.

## Activation policy

Physical hosts stage input upgrades with `boot`, then reboot deliberately.
Cloud hosts may use `switch` only when the candidate leaves kernel, systemd,
bootloader, networking, and GPU-related closures unchanged; otherwise they also
stage and reboot.

`switch-all` is forbidden for input and nixpkgs upgrades. It remains available
for already-proven, low-risk config-only changes.

Prebuild first, then roll out sequentially:

1. vanguard
2. voyager
3. pathfinder
4. laptop
5. orion
6. kepler
7. discovery

Archinaut uses a separate manual window because its Wi-Fi, aarch64,
kernel-direct boot, and printer UART constraints are unique.

## Verification and stop rules

Boot counting decides only whether the operating system booted. Application
health must not control generation blessing; prior aggressive coupling caused
reboot loops.

After each reboot, run host-specific service probes, `systemctl --failed`,
revision confirmation, and ESP measurement. Do not touch the next host until
the current host is green. A failed probe stops the rollout; the operator may
select the previous generation or fix forward.

## Remaining implementation

- Make `update-safe` preserve and restore a clean lock file without Git
  checkout.
- Add an impact-scoped upgrade preflight with candidate-size ESP projection.
- Encode sequential rollout and the physical/cloud activation policy.
- Record alert-drill freshness and intentional host exclusions.
- Update `switch-all` help text to state its config-only boundary.
- Add a first-class post-switch verifier so a reload failure can be separated
  from an activation failure without ad-hoc remote commands.

Existing 512M ESP migration is governed by the fleet ESP enlargement RFC.
