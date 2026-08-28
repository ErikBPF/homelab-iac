# Fleet alerting reliability and response

**Status:** In progress — inherited alerting is live; source/runtime drift,
owner-correct status tooling, delivery drills, and observation remain
**Date:** 2026-08-28
**Last reviewed:** 2026-08-28
**Owners:** `homelab` (cross-repository contract and evidence),
`homelab-gitops` (Grafana rules, routing, and Kubernetes monitoring),
`desktop-nixos` (host signals, diagnostics, and external dead-man), and
`servarr` (Discovery workload signals and runbooks)

## Decision

This is the canonical alerting proposal. It fuses the remaining work from:

- [alert reliability improvements](2026-08-14-alert-reliability-improvements.md);
- [runtime security monitoring](2026-07-25-runtime-security-monitoring.md).

Their implementation histories remain immutable evidence. This record owns the
current cross-plane contract: truthful detection, one notification owner per
event class, safe delivery, actionable response, bounded drills, and closure
evidence.

The [Wazuh SIEM proposal](2026-07-26-fleet-wazuh-siem-integration.md) stays
separate. Agent enrollment, retention, credentials, Kubernetes audit, and SIEM
restore have different risk and ownership. This proposal consumes Wazuh canary
evidence and prevents duplicate notification ownership; it does not absorb the
platform rollout.

## Grounded current state

Source and read-only runtime checks on 2026-08-28 establish:

- `homelab-gitops` owns the live Kubernetes monitoring deployment and its
  provisioned Grafana alert files. The old Servarr monitoring runtime is
  retired.
- Grafana has 57 provisioned rules, including four `category=security` rules.
- The active notification path is Grafana to native Discord. Provisioning
  tombstones both former Cleytin webhook contact points; the Kubernetes cutover
  deliberately removed that unreachable route.
- Monitoring pods are ready. Prometheus reports `up{job="node-vanguard"}=1`, so
  the old Vanguard scrape gate is closed.
- Grafana reported six active alert instances:

| Alert | Classification | Disposition |
|---|---|---|
| Argo CD app out of sync: `traefik` | Truthful control-plane drift | Reconcile desired/live state; do not silence. |
| Argo CD app out of sync: `monitoring` | Truthful control-plane drift | Reconcile desired/live state; do not silence. |
| Argo CD app out of sync: `loki` | Truthful control-plane drift | Reconcile desired/live state; do not silence. |
| Discovery `homelab-iac-drift.service` failed | Truthful producer failure; Sops state decryption lacked an available key | Repair the owning job/key path; retain the alert. |
| Kepler `nix-gc.service` failed | Truthful host failure; Nix store cleanup returned `Structure needs cleaning` | Handle under the Kepler recovery/stateful gate; retain the alert. |
| UniFi SIEM stream silent | Stale provisioned rule; its source metric was intentionally removed | Add the known UID `security-control-unifi-siem-silent` to `deleteRules`. |

- `desktop-nixos` host alert tests pass, but its `grafana-alert-status` recipe
  still queries the retired Docker Grafana and fails with `No such container:
  grafana`. Status tooling must follow the Kubernetes owner.
- The previous Orion Wazuh canary and encrypted restore are proven. The current
  `verify-wazuh-agent-canary` run did not find its expected local container, so
  the historical proof stands but the recipe is not a current live gate until
  its owner reconciles that mismatch.

No credential value, Discord payload, or Wazuh event content was recorded.

## Product and architecture shaping (`/pl`)

### Destination

An operator can ask what is alerting, distinguish monitoring failure from a
workload failure, reach one safe notification, follow an owned response path,
and prove recovery without suppressing a real incident.

### Bounded party ledger

| Perspective | Required outcome | Tension and resolution |
|---|---|---|
| Operator | One accurate queue and an owner-correct status command | Preserve real Argo/systemd alarms; repair causes instead of thresholds. |
| Platform owner | GitOps owns Grafana lifecycle and provisioning | Move the status seam to `homelab-gitops`; callers may delegate, never copy it. |
| Security | Value-free payloads and no detection gap after Cleytin retirement | Native Discord remains the sole Grafana route; force-fire one existing security rule. |
| Reliability | Firing and resolved delivery, independent total-outage detection | Reuse the current Discord contact points and Vanguard dead-man. |
| SIEM owner | Wazuh events are attributable and not duplicated | Keep Wazuh platform work separate; assign one notifier owner per event class. |

### Decision map

Settled decisions:

1. `homelab-gitops` is the runtime owner for Grafana rules, routing, and alert
   inventory. Host and workload repositories own only their signal producers
   and diagnostics.
2. Native Discord is the sole Grafana delivery path. Do not restore Cleytin,
   add Alertmanager, or create another deduplication service without a measured
   gap.
3. A missing or stale telemetry identity produces a telemetry alert, not a set
   of invented workload-down alerts.
4. Source deletion is incomplete until a Grafana provisioning tombstone and a
   live absence check prove removal.
5. True failures stay visible while their owners repair them. Blanket silences,
   longer thresholds, and Grafana database resets are rejected.
6. Drills are isolated, staffed, bounded, and reversible. Firing and resolved
   delivery are both evidence gates.
7. Evidence is value-free: revision, rule UID/title, class, timestamps,
   delivery result, recovery result, and owner only.

Dependencies and fog:

- Argo drift must be explained before reconciliation; health alone does not
  authorize overwriting live differences.
- The Discovery Sops failure and Kepler filesystem error belong to their
  producer/recovery owners. This proposal tracks their alert response only.
- Discord receipt and operator usefulness require a staffed external check;
  source rendering cannot prove either.

Out of scope: new telemetry backends, automatic remediation, broad threshold
tuning, full Wazuh rollout, incident-chat agents, and simultaneous outage
drills.

### Behavior contract

[`docs/behaviors/fleet-alerting/alerting.feature`](../behaviors/fleet-alerting/alerting.feature)
is the accepted cross-repository behavior contract. It remains tagged
`@unautomated`; existing shell and Python tests cover source seams, but no BDD
runner binds these scenarios today.

### Plan grill

Rejected alternatives:

- **Fuse the entire Wazuh proposal:** obscures separate enrollment, retention,
  credential, and restore risk.
- **Restore Cleytin to satisfy old prose:** recreates an unreachable retired
  path and a second delivery owner.
- **Tune or silence the six active alerts:** hides five real conditions and
  leaves the one stale provisioned rule in Grafana's database.
- **Reset Grafana state:** excessive blast radius when one UID tombstone is the
  exact repair.
- **Build a new alert inventory service:** the Grafana API and existing `just`
  command pattern already provide the seam.

## Implementation plan (`/ip`)

Order is leaf-first: producer corrections, owned GitOps changes, exact deploy,
live proof, then observation. Every slice stops on unexpected active-alert
loss, secret-shaped output, unrelated drift, or failed rollback readiness.

### A1 — restore trustworthy read-only inventory

- **RED:** a contract proves the current desktop recipe fails against retired
  Docker and requires `active=N`, unavailable/error distinction, and no secret
  output from the Kubernetes-owned path.
- **GREEN:** add the smallest owner command in `homelab-gitops` and retire the
  stale desktop command. Do not create a cross-working-tree runtime dependency.
- **Verify:** run the source contract and compare its titles/count with one
  authenticated read-only Grafana API response.
- **Rollback:** revert the delegation; retain direct value-free API procedure
  for diagnosis.

### A2 — delete the orphaned UniFi rule

- **RED:** extend `tests/monitoring-contract.sh` to require a `deleteRules`
  entry for `security-control-unifi-siem-silent` while continuing to reject its
  removed metric expression.
- **GREEN:** add that one tombstone to the existing alert rule file.
- **Verify:** render the monitoring chart, sync its reviewed revision, and
  prove only that rule disappears from Grafana's active/rule inventory.
- **Rollback:** revert the tombstone only if the metric producer and an accepted
  owning proposal are restored together.

### A3 — reconcile truthful Argo drift

- **RED:** capture `argocd app diff` separately for `traefik`, `monitoring`, and
  `loki`; classify desired, admission/defaulting, and operator-owned fields.
- **GREEN:** correct the smallest owning source or reviewed ignore rule. Never
  apply a broad ignore or overwrite unexplained live state.
- **Verify:** each application is `Synced` and `Healthy`; monitoring readiness,
  datasource health, and active-alert inventory remain available.
- **Rollback:** resync the last known-good revision for only the affected app.

### A4 — repair producers without weakening alerts

- **RED:** preserve diagnostics for the Discovery Sops decryption failure and
  Kepler `Structure needs cleaning` error; reproduce only in the owning safe
  test seam.
- **GREEN:** repair the Discovery key-access/job path in its owner. Route the
  Kepler filesystem issue through the existing fleet-upgrade/stateful recovery
  gate; do not reset the failed unit as a substitute for repair.
- **Verify:** the owning job succeeds, Grafana resolves naturally, and no other
  alert instance disappears.
- **Rollback:** restore the previous producer revision; the unchanged alert
  remains the safety signal.

### A5 — prove delivery and truthful degradation

- **RED:** record the expected firing/resolved pair, safe fields, exact receiver,
  and recovery deadline before each drill.
- **GREEN:** sequentially run one existing Grafana security-rule force-fire,
  the bounded Alloy identity drill, and the separate Loki availability drill.
  Reuse native Discord and existing diagnostics; add code only for an observed
  defect.
- **Verify:** one firing and one resolved notification arrive per drill, payloads
  are value-free, telemetry loss is not reported as workload loss, and the
  Vanguard dead-man remains independent.
- **Rollback:** end the injected condition immediately and restore the reviewed
  revision; abort later drills on failed recovery.

### A6 — observe and close

- Observe seven days after A1–A5. Review duplicates, false positives, delivery
  failures, mean acknowledgement/recovery time, and unresolved active alerts.
- Close only when all source tests pass, Grafana inventory matches provisioned
  intent, the active queue contains no stale rule, delivery and recovery
  evidence exist, and every remaining alert has an owner and next action.
- Reopen for a missing page, duplicate ownership, unsafe payload, false
  workload diagnosis, or monitoring outage reported as `active=0`.

## Dependency and verification matrix

| Order | Owner | Source check | Live gate |
|---:|---|---|---|
| 1 | `homelab-gitops` | `bash tests/monitoring-contract.sh` | owner-correct `active=N` inventory |
| 2 | `homelab-gitops` | chart render and exact UID tombstone | stale UniFi rule absent |
| 3 | `homelab-gitops` | per-app diff | three apps `Synced`/`Healthy` |
| 4 | producer owners | focused unit/contract checks | jobs succeed; alerts resolve naturally |
| 5 | all alert owners | existing host/GitOps contracts | firing/resolved Discord and bounded drill proof |
| 6 | `homelab` | `bash tests/contracts.sh` | seven-day review accepted |

## Completion evidence

Append only value-free results here as slices land. Do not mark the proposal
complete from source tests alone.
