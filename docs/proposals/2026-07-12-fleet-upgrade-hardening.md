# Fleet upgrade contract

**Status:** Kepler Linux 7.2 candidate rejected after repeated runtime crashes;
rollback/pin, runtime-soak, and independent monitoring gates are open alongside
the existing candidate, ESP, sequential-rollout, and evidence work — 2026-08-27.

## Purpose

Give a fresh operator one safe path for flake-input upgrades. The contract is
impact-scoped: fleet-wide gates apply to inputs that affect shared system
closures; leaf inputs apply only to their consumer hosts.

## Already implemented

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
K3s HA test completed in 551.78 seconds. Endeavour, Discovery, Pathfinder, Orion,
Kepler, and Voyager report the target nixpkgs revision. Voyager's offsite
receiver was recreated from the published Servarr revision and reports healthy.
Archinaut was unreachable and remains an explicit manual-window exclusion.
The historical note that Telstar and Vanguard lacked fleet-status tailnet
addresses is closed: current fleet metadata records both. Gemini and the
Home Assistant appliance are not NixOS fleet-upgrade targets.

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
4. endeavour
5. telstar
6. orion
7. kepler
8. discovery

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

## Revised decision map — 2026-08-25

### Settled

- The current managed NixOS set is `archinaut`, `discovery`, `endeavour`,
  `kepler`, `orion`, `pathfinder`, `telstar`, `vanguard`, and `voyager`.
- Existing `deploy-rs` and `deploy-rs-boot` paths remain the activation
  mechanisms. This proposal adds no deployment framework.
- `switch-all` remains a convenience for already-proven config-only changes;
  it must fail closed when `flake.lock` changes.
- Input upgrades are sequential. A host failure stops the run before the next
  activation.
- Value-free evidence records the candidate, affected/excluded hosts,
  activation mode, verification result, and catch-up window.

### Still open

- The exact impact classifier must be proven against evaluated host closures;
  filename heuristics alone are not an authorization boundary.
- ESP projection needs one reviewed calculation seam that uses realized
  candidate artifacts and live host capacity.
- The 72-hour soak and 90-day alert-drill freshness gates need a small retained
  evidence format. No database or service is justified.

The behavior contract is
[`../behaviors/fleet-upgrade/upgrade.feature`](../behaviors/fleet-upgrade/upgrade.feature).
It is a reviewed, unautomated contract until its scenarios have runnable step
bindings and are observed failing before implementation.

## Vertical implementation plan

Land in `desktop-nixos`; keep each slice independently revertible.

| Slice | RED seam | Minimum GREEN change | Verification and rollback |
|---|---|---|---|
| U0 — command contract | Add `tests/fleet-upgrade/test_contract.py` assertions for clean-lock refusal, config-only `switch-all`, fleet enumeration, stop-on-failure, and value-free evidence; observe failures. | No production change. Freeze command names and evidence fields only. | `pytest -q tests/fleet-upgrade/test_contract.py`; revert the test commit if the contract changes before acceptance. |
| U1 — safe candidate | Tests require a temporary lock copy plus trap-based restore and forbid `git restore`/`git checkout` in the candidate path. | Correct `update-safe`; add one candidate recipe that records exact before/after revisions without secrets. | Focused test, then `just update-safe` against a disposable clean worktree; rollback restores the saved lock bytes. |
| U2 — impact and ESP gate | Fixtures cover one leaf input, one shared input, 50% warning, 25% block, and unreachable-host failure. | Add the smallest script that evaluates affected toplevels and projects candidate plus known-good ESP use from realized artifacts and live measurements. | Focused tests plus dry runs on one workstation and one 512 MiB-ESP server; remove the script/recipe to rollback. No activation occurs. |
| U3 — sequential activation | A fake runner proves one in-flight host, reviewed order, config-only rejection, exclusion/catch-up recording, and immediate stop after a failed verifier. | Add one orchestration recipe delegating to existing `deploy-rs` or `deploy-rs-boot`; do not duplicate deployment logic. | Contract test, then a config-only canary. Rollback is stop plus the existing previous-generation/deploy-rs path. |
| U4 — post-activation proof | Fixtures reject missing revision, failed units, reachability, required host probes, ESP measurement, or secret-shaped fields. | Add one verifier/evidence writer and reuse existing host diagnostics. | Focused test, `just check`, then one reviewed canary and synthetic failed-unit alert-freshness proof. Keep the proposal open until excluded hosts catch up. |

Leaf-first order is U0 → U1 → U2 → U3 → U4. U3 cannot activate anything
until U1/U2 pass for the exact candidate. Physical activation and live alert
drills require an approved maintenance window.

## Plan grill and review

- **Correctness:** evaluated closures, not path guesses, decide impact; candidate
  and known-good boot artifacts both count toward ESP reserve.
- **Reliability:** orchestration delegates existing deploy commands, permits one
  in-flight host, and stops on the first failed verifier.
- **Security:** evidence is allowlisted and value-free; no Sops/Vault contents,
  raw environment, or command output are retained.
- **Simplicity:** no controller, queue, daemon, or new deployment tool. One test
  file, at most two bounded helpers, and `just` entry points are the expected
  ceiling.
- **Editorial:** historical rollout evidence remains historical; current host
  names and remaining work are stated separately.

## Kepler Linux 7.2 incident addendum — 2026-08-27

### Observed evidence

- Kepler booted Linux `7.2.0`, loaded the NVIDIA `595.91.07` driver, and returned
  its GPU and Kubernetes workloads, but then restarted unexpectedly at least
  three times in less than one hour.
- The retained previous-boot journal contains `NOHZ` softirq warnings, two
  kernel page faults in `virtiofsd` processes through futex wake/unqueue paths,
  and an RCU stall involving another `virtiofsd` process. The NVIDIA and ZFS
  modules taint the kernel, so this identifies the failing path, not a proven
  upstream root cause.
- Lockup panic plus `panic=10` converted the otherwise unreachable host into a
  reboot and preserved useful journal evidence. systemd-boot counting did not
  roll back because the generation had already reached and passed boot
  blessing before the runtime failure.
- All Kubernetes nodes, Prometheus, Grafana, Loki, and their persistent volumes
  still share the Kepler physical failure domain. The current external dead-man
  probes Home Assistant, not a Kepler/Kubernetes-owned endpoint.
- `just grafana-alert-status` still targets the retired Discovery Compose
  container. The live Kubernetes Grafana eventually reported a Prometheus
  datasource error, but only after Kepler and the monitoring plane returned.
- The pending `desktop-nixos` Kepler cold-restart contract predates both the
  monitoring cutover and the lockup recovery. Its Compose-monitoring and
  no-runtime-watchdog assumptions are stale and must not be implemented as-is.

### Decision map

#### Settled now

- Reject Linux 7.2 as a Kepler **host** candidate and restore the known-good
  Linux 6.18 host kernel. Pin that host explicitly and suspend its unattended
  activation/reboot while this incident remains open.
- Kernel uniformity is not an acceptance goal. Physical-host and MicroVM guest
  kernels are separate candidates; a working 7.x guest or another 7.x host
  does not authorize 7.x on Kepler.
- Keep the lockup detectors, `panic=10`, and persistent journal. They improve
  recovery and evidence but do not count as rollback or candidate acceptance.
- Keep runtime-crash rollback operator-controlled. Do not add an automatic boot
  selector until a disposable test proves it cannot loop or demote a healthy
  generation because of a workload or storage fault.
- Replace the retired Compose alert-status path with one Kubernetes-owned,
  read-only path. Monitoring-plane unreachable must be an error, never
  `active=0`, and credentials must remain inside the target pod or sanctioned
  runtime secret boundary.
- Reuse Vanguard's existing dead-man service and independent webhook. Give it a
  Kepler/Kubernetes-owned readiness target and force-fire it before claiming
  monitoring cutover complete; add no second monitoring stack.
- Reconcile the pending cold-restart contract with Kubernetes monitoring and
  the now-enabled lockup recovery before implementation. Keep its storage
  fail-closed and 10-minute return behaviors unchanged.

#### Evidence gates before another Kepler host kernel candidate

1. The exact candidate closure and previous generation are retained and the
   deployment is staffed with console or Home Assistant `tomada_kepler` power
   recovery available.
2. Kepler completes at least 60 minutes under its real MicroVM/virtiofs, ZFS,
   GPU, and Kubernetes load without a boot-ID change, kernel oops, panic, RCU
   stall, failed required unit, or lost GPU/cluster readiness.
3. A 24-hour observation period remains free of the same failures before the
   candidate is accepted or used to justify a wider host rollout.
4. The Kubernetes alert-status path, Prometheus datasource rule, and Vanguard
   dead-man each produce a distinct, value-free verdict.

The 60-minute gate is a minimum derived from the observed failures occurring
within roughly 25 minutes. It supplements the existing 72-hour publication
soak; neither substitutes for the other.

#### Diagnostic branch

- If Linux 6.18 remains stable for 24 hours with the current userspace, guest
  kernels, and workload, classify Linux 7.2 host behavior as the leading
  regression and reproduce it only in a staffed or disposable environment
  before an upstream report or retry.
- If Linux 6.18 also crashes, stop blaming the version. Keep workloads safe,
  disable MicroVM autostart for the next diagnostic boot, and isolate RAM,
  virtiofs, ZFS, and GPU paths one at a time. Do not change multiple variables
  in one trial.

### Ownership and handoff

- `desktop-nixos`: Kepler host pin/upgrade hold, kernel-soak verifier, current
  Kubernetes alert-status recipe, dead-man target, and focused contracts.
- `homelab-gitops`: keep the datasource-health rule and Kubernetes monitoring
  readiness observable; no new alerting service.
- `homelab`: retain the incident decision/evidence and block fleet acceptance
  while the Kepler gate is red.

The addendum's behavior is appended to the existing
[`upgrade.feature`](../behaviors/fleet-upgrade/upgrade.feature). It is ready for
`$ip`; no implementation or deployment is authorized by this planning update.
