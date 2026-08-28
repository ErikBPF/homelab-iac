# Alert reliability improvements — truthful container state and actionable job failures

**Status:** Superseded by
[fleet alerting reliability and response](2026-08-28-fleet-alerting-reliability-and-response.md);
implementation history retained, with remaining drills and observation moved
to the canonical record
**Date:** 2026-08-14
**Last reviewed:** 2026-08-25
**Owners:** `desktop-nixos` (collector startup and host diagnostics), `servarr`
(Grafana rules, tests, and runbook), and `homelab` (cross-repository gates and
evidence)

> Historical ownership note: Grafana moved from Servarr Compose to
> `homelab-gitops` after this implementation. The body below records the work as
> executed; it is not current operational guidance.

## Goal

Make the current alerts describe facts the monitoring path can prove:

- one container-telemetry alert when container identity is unavailable, not
  seven false workload-down alerts;
- one workload alert when a named critical container is actually missing,
  stopped, or stale while telemetry is healthy;
- one useful path from a generic failed-systemd-unit alert to evidence,
  bounded recovery, and verified recovery.

Reuse Alloy, cAdvisor, node exporter, Grafana, Loki, and the existing `just`
recipes. This proposal adds no monitoring service, exporter, datastore,
automatic remediation, or blanket threshold change.

## Trigger and verified state

A read-only check on 2026-08-14 returned `active=8`:

| Alert | Count | Verified interpretation | Immediate disposition |
|---|---:|---|---|
| `Critical container down (>2 min)` on Discovery | 7 | False workload diagnosis. Loki, PostgreSQL, AdGuard, Vault, Grafana, Prometheus, and SWAG were independently healthy. Prometheus had 128 raw Discovery `container_last_seen` series but none with a `name` label. | Keep visible until the producer and rule fixes deploy; do not stop or recreate healthy workloads. |
| `systemd unit failed on host` for Orion `nix-cache-builder.service` | 1 | Real failed unit. Retained Loki logs show source fetches failed because `codeload.github.com` and `download.nvidia.com` could not resolve; the failure propagated through `nvidia-persistenced` to Kepler's system closure. Classify as transient DNS/transport failure. | After checking Orion capacity, use the existing manual `just recache-orion`; require `Result=success` and Grafana recovery. |

The recent Discovery `homelab-iac-drift.service` warning was not active in the
same check. Its failed run completed 20 of 21 plans and failed the Oracle
budget lookup on DNS. The existing guarded
`just grafana-alert-retry discovery-drift` path already owns that recovery; no
new retry mechanism is justified.

### Container root cause

Discovery boot evidence establishes a producer startup race:

1. Alloy started at `19:57:14Z`.
2. Docker started at `19:57:21Z`.
3. cAdvisor timed out registering its Docker factory at `19:58:32Z`.
4. Docker's API became ready at `19:58:33Z`.
5. cAdvisor did not retry factory registration, so it exported raw cgroup
   series without Docker container-name labels.

The Grafana rule treats each missing name as a stopped container. One telemetry
failure therefore became seven critical workload instances. Longer `for`
durations would only delay the same false diagnosis.

## Decisions

### D1 — fix the producer before changing thresholds

In `desktop-nixos`, order Docker-enabled Alloy after `docker.service` and add a
weak want for it. Do not use `Requires=`: if Docker fails, Alloy must still
start and export host telemetry.

Add the contract to the existing
`tests/alloy-containers/test_alloy_containers.py`; do not create another module
or startup wrapper.

### D2 — separate telemetry health from workload health

In Servarr's existing `containers` alert group:

1. Add one Discovery container-telemetry rule. It fires when fresh
   `container_last_seen{host="discovery",name!=""}` identity is absent or
   stale.
2. Gate only the Discovery branches of `container-critical-down` on that same
   fresh named-telemetry predicate.
3. Preserve the current 120-second stale test and five-minute `for` duration.
   The incident does not contradict either value.
4. Leave the unaffected Kepler Podman branches unchanged.
5. Give the telemetry and workload rules distinct summaries and a shared
   runbook URL.

When the collector cannot identify containers, Grafana can prove a telemetry
failure but cannot prove seven container outages. The telemetry alert is the
truthful page until identity returns.

### D3 — keep the generic systemd rule; improve its response path

The generic `host-systemd-unit-failed` rule correctly reported both the cache
builder and drift failures. Do not replace it with per-job Grafana rules.

Add its runbook URL and extend the existing fixed diagnostic allowlist to
include Orion's `nix-cache-builder.service`. The runbook must map:

- cache builder: status, central Loki logs, resource use, failure
  classification, existing `just recache-orion`, then `Result=success` and
  Grafana recovery;
- IaC drift: status and plan summary, unexpected-checkout guard, existing
  `just grafana-alert-retry discovery-drift`, then recovery verification.

No automatic retry ships in this slice. The cache job consumed about 56.6 GB
peak memory and two CPU-hours in the observed failure; retrying an unknown
build defect automatically is neither bounded nor cheap. Admit one automatic
retry later only after repeated evidence identifies transport-only failures.

### D4 — make existing diagnostics preserve the causal evidence

Extend, rather than duplicate, the current `desktop-nixos` recipes:

- `verify-container-metrics` reports raw and named series for every compose
  host before returning failure;
- `diagnose-container-metrics` includes Docker state and the current-boot Alloy
  factory-registration lines, not only the last ten minutes;
- `grafana-alert-diagnostics` includes the cache builder and points operators
  to retained Loki evidence when the local journal rotated.

Diagnostics remain read-only. Recovery stays in the existing explicit
recipes.

## Delivery order and gates

| Gate | Change or evidence | State |
|---|---|---|
| G0 — current incident | Retained Loki evidence classifies the cache failure as transient DNS/transport. Run the existing manual retry after a capacity check and record service plus alert recovery. | Cause recorded; manual retry open |
| G1 — producer contract | Add a failing `desktop-nixos` contract for `After=`/`Wants=` Docker ordering and improved all-host diagnostics. | Complete locally |
| G2 — producer fix | Land and deploy the smallest `alloy-containers.nix` ordering change, restart only Alloy after Docker is ready, and require all seven expected Discovery names within two scrapes. | Implemented and dry-built; deploy evidence open |
| G3 — rule contract | Add a failing Servarr contract proving telemetry loss creates one telemetry result and suppresses Discovery per-container absence results. | Complete locally |
| G4 — rule and runbook | Change the existing provisioned rules, tests, and Discovery runbook; validate them in the local Grafana rig; deploy through the existing Servarr workflow. | Implemented and query-checked; Grafana rig and deploy open |
| G5 — live proof | In an approved maintenance window, stop Alloy for less than the host-alert window and prove one telemetry alert plus recovery. Separately stop Loki long enough to prove one workload alert plus recovery. | Blocked on G4 |
| G6 — observation | Review seven complete days for container fan-out, stale recovery, and failed-unit response friction. Tune only defects supported by that evidence. | Blocked on G5 |

Land `desktop-nixos` producer and diagnostic changes first, then the Servarr
consumer rule. Publish and deploy committed revisions; no build or deployment
may read another working tree.

## File budget

Expected implementation surface:

- `desktop-nixos/modules/services/alloy-containers.nix`;
- `desktop-nixos/tests/alloy-containers/test_alloy_containers.py`;
- existing diagnostic recipes in `desktop-nixos/justfile`;
- Servarr's provisioned Grafana rules, existing container-observability test,
  and Discovery runbook.

No new repository, daemon, exporter, dashboard, or recovery script is in
scope.

## Local implementation record — 2026-08-14

- `desktop-nixos` contracts failed on all three missing behaviors, then passed
  after the minimal change: Alloy now has `After=` and `Wants=` for Docker,
  container verification reports raw and named counts for all hosts, collector
  diagnosis preserves current-boot factory evidence, and failed-unit
  diagnostics cover the cache builder.
- The focused desktop suite passes `5/5`; `just lint`, `just fmt-check`, and
  `just dry discovery` pass. Evaluated Discovery config contains
  `docker.service` in Alloy's `after` and `wants` lists and no new hard
  requirement.
- Live read-only diagnostics reported Discovery `raw_containers=128` and
  `named_containers=0`, while Kepler reported `27/27` and Orion `7/7`. The
  concise boot diagnosis reproduces Alloy active at `16:57:14`, Docker active
  at `16:58:33`, and Docker factory registration timing out one second before
  Docker became ready.
- Servarr contracts failed before the telemetry rule, workload gate, and
  runbook existed, then passed `6/6`. The relevant container plus Grafana
  contract set passes `14/14`.
- Both proposed PromQL expressions parsed against live Prometheus. Under the
  current failure, the telemetry expression returned exactly one
  `{host="discovery"}` result and the gated critical-container expression
  returned zero results.
- Retained Loki logs prove the cache build's terminal dependency chain began
  with DNS failures resolving `codeload.github.com` and
  `download.nvidia.com`. A manual retry is justified but remains deliberately
  open because the failed run consumed 45 minutes, two CPU-hours, and 56.6 GB
  peak memory.
- The broader Discovery suite passed 142 tests and 42 subtests. One unrelated
  AdGuard fixture could not resolve its unqualified image through the local
  Podman-compatible Docker frontend; the focused alert and YAML-loading tests
  remain green.
- Implementation merged through `desktop-nixos` PR
  [#185](https://github.com/ErikBPF/desktop-nixos/pull/185) and Servarr PR
  [#239](https://github.com/ErikBPF/servarr/pull/239); nothing was deployed,
  restarted, or force-fired.

## Operational follow-up — 2026-08-16

- Transient Discovery wiki seed, offsite restic, and IaC drift failures
  recovered without workload recreation. Orion's retained logs proved DNS
  failure; only failed state was reset, and the 56.6 GB cache build was not
  retried automatically.
- `desktop-nixos` PR
  [#187](https://github.com/ErikBPF/desktop-nixos/pull/187) adds bounded retries
  to the cheap wiki/restic jobs and deploys pinned IaC/Telstar execution.
- Telstar's exact remote lock remains. The command maps an emitted lock error to
  exit 75 without a systemd restart; the live backend call stayed blocked before
  emitting it, so the exact retry unit was paused. Force-unlock requires the
  exact UUID and refuses an active writer; none was run.
- Grafana now reports `active=3`, all for unavailable Airflow API, scheduler,
  and DAG-processor replicas. Runtime secrets are in Vault and the
  digest-pinned GitOps release is manual; rollout waits for a pull-only robot
  because the Vault admin credential returns HTTP 401 from live Harbor.
- After approved Harbor recovery, pull-only robot creation, and exact-revision
  Airflow sync, all seven ExternalSecrets are healthy and the replacement API,
  scheduler, and DAG-processor pods are Ready with zero restarts. The existing
  `grafana-alert-status` path reports `active=0`; the three image-pull alerts
  recovered without widening `library` or reusing a privileged robot.

## Operational follow-up — 2026-08-17

- `just recache-orion` ran under observation. The first retry warmed seven host
  closures but left Discovery with two failed dependencies after 23 minutes;
  the immediate cached retry completed every closure in eight seconds.
  `nix-cache-builder.service` is inactive with `Result=success`, its timer remains
  armed, and Orion's post-reboot failed-unit gate is empty. No automatic retry
  or new recovery path was added.

## Risks and rollback

- Docker ordering can delay Alloy during a slow Docker boot. `Wants=` plus
  `After=` avoids coupling Alloy's success to Docker's success.
- Gating workload absence on healthy telemetry intentionally hides exact
  workload state while identity is unknowable. The critical telemetry alert
  remains visible; independent endpoint and host alerts continue unchanged.
- Live drills temporarily remove logs or Loki availability. Keep each bounded,
  announce the window, and restore the service before starting another drill.
- Cache retries are resource-heavy. Keep them manual until recurrence evidence
  supports a safe retry ceiling.

Rollback the Servarr rule commit if evaluation errors or missed workload
results appear. Roll back the Alloy ordering commit if Alloy fails to start;
the current generic host and endpoint alerts remain the safety net. Neither
rollback changes stored data.

## Completion criteria

Close this proposal only when:

- a Discovery maintenance reboot proves Docker is ready before cAdvisor
  registration and named container series return within two scrapes;
- collector loss produces one container-telemetry alert and zero false
  Discovery workload-down instances, then recovers;
- a controlled Loki stop produces exactly one expected workload alert, then
  recovers;
- the current cache failure has a recorded cause and either a successful
  follow-up run or a separately owned build defect;
- cache and drift failures can be diagnosed and recovered through documented
  existing commands without inventing an ad hoc path;
- the seven-day review finds no unexplained fan-out or stuck alert.

Threshold changes, automatic recovery, and broader alert taxonomy remain
out of scope unless the evidence creates a new narrow trigger.

## Superseded execution-plan snapshot — 2026-08-25

Behavior review found no remaining decision: G5 and G6 are operational proof,
not a new implementation. Run them as two staffed slices:

1. **G5 drills:** capture the healthy baseline; stop Alloy for less than the
   host-alert window; prove exactly one telemetry alert, zero false per-workload
   alerts, and recovery. Restore Alloy and baseline before the separate bounded
   Loki drill, which must produce the expected workload alert and recovery.
2. **G6 observation:** retain seven complete days of alert fan-out, recovery,
   and failed-unit response evidence. Close only if every completion criterion
   above is met; otherwise open one narrow defect against the owning producer or
   rule.

The RED evidence is any wrong count, missing recovery, unsafe payload, or stuck
state. GREEN is the existing rule/collector behavior plus value-free timestamps
and counts. Final review rejects new retry automation, thresholds, dashboards,
or services without evidence from these two slices.
