# Observability continuation — execution plan

**Status:** In progress. B0 completed 2026-07-28. The 2026-08-01 B1 retry
proved scheduled gauge advances and fresh snapshots in all intended
repositories; direct successful-job log correlation remains open because the
historical Ofelia logs had rotated. A0 completed for the exact seven-day
window, and A1 closed with no threshold tuning required.

## 1. Purpose and authority

This plan executes only the active remainder in
[`2026-07-03-observability-continuation.md`](2026-07-03-observability-continuation.md).
The proposal remains authoritative for scope and ownership.

There are two mandatory slices:

1. prove the three Kepler backup gauges from real scheduled jobs;
2. review a complete seven days of Grafana alert history and tune only
   evidence-backed defects.

Everything else remains a decision gate. A gate without its named trigger
produces no implementation work.

## 2. Ownership and order

| Repository | Responsibility in this plan |
|---|---|
| `desktop-nixos` | Existing live backup seed command and host-side diagnostics |
| `servarr` | Kepler backup jobs; Prometheus, Grafana rules, dashboards, and tests |
| `homelab-gitops` | No planned change; becomes active only for an admitted control-plane scrape |
| `homelab-iac` | No planned change; UniFi account remains manual and gated |

Order:

`B0 backup proof → wait for scheduled rollover → B1 scheduled proof → 2026-08-01 A0 history capture → A1 minimal tuning → close or admit a named gate`

Do not mix Servarr alert changes with unrelated dirty work. Land owner-local
changes first, then deploy through `desktop-nixos`.

## 3. B0 — seed and prove backup metrics

This is an operational evidence slice, not a code-change slice.

### Preflight

1. Confirm Kepler is on the expected `desktop-nixos` and `servarr` revisions.
2. Confirm `postgres`, `restic`, `restic-offsite`, Ofelia, and node exporter
   are healthy.
3. Record current values, or absence, for:
   - `restic_kepler_postgres_last_success_seconds`
   - `restic_kepler_configs_last_success_seconds`
   - `restic_kepler_offsite_last_success_seconds`
4. Record the latest local and offsite Restic snapshots. Do not expose
   credentials or repository passwords.

### Execute

From `desktop-nixos`, run the existing idempotent recipe:

```bash
just seed-kepler-backup-metrics
```

Do not add another script. The recipe already initializes absent repositories,
runs real backups, writes gauges atomically only after success, and checks that
all three metric files exist.

### Verify

1. Query Prometheus for each exact metric name.
2. Require exactly one series per metric, a timestamp newer than the preflight
   value, and an age below the configured stale threshold.
3. Confirm the local Restic repository contains the `postgres` and `configs`
   snapshots and the offsite repository contains the `configs` snapshot created
   by this run.
4. Confirm the backup dashboard shows all three gauges and no missing-series
   state.
5. Confirm the corresponding Grafana rules evaluate normally. Do not
   force-fire stale alerts by damaging or deleting backup state.
6. Save timestamps, snapshot IDs, Prometheus results, dashboard query results,
   and alert states in the proposal's implementation record.

Stop on repository initialization failure, authentication failure, missing
snapshot, duplicate Prometheus series, or a gauge written despite backup
failure. Fix the root cause in `servarr`; do not hand-write a metric.

## 4. B1 — prove the scheduler, not only the seed command

After the next complete daily backup window:

1. Re-query all three gauges.
2. Require every value to have advanced without rerunning the seed recipe.
3. Match each value to a successful Ofelia job log and a corresponding Restic
   snapshot.
4. Pay special attention to `restic_kepler_offsite_last_success_seconds`;
   prove the snapshot exists in the offsite repository, not merely that the
   metric file changed.

B0 plus B1 closes the backup-gauge remainder. If any value fails to advance,
open one narrow Servarr fix for the failing job, add or adjust the smallest
existing backup-job contract, run the Kepler tests, deploy, then repeat B1.

### B0 implementation record — 2026-07-28

- Restored Kepler-to-Voyager access and fixed the offsite repository path
  required by `rest-server --private-repos`.
- Merged `homelab-iac#41`, `desktop-nixos#132`, and Servarr `#137`, `#138`,
  and `#139`.
- Permanently activated the `desktop-nixos#132` pull fix on Voyager on
  2026-07-29; the host returned with no failed units, a healthy Podman API,
  and a healthy Restic receiver.
- Seed completed successfully at `2026-07-28T23:53:00Z`.
- Gauges: postgres `1785282679`, configs `1785282680`, offsite `1785282780`.
- Prometheus returned exactly one series for each gauge with the same values.
- Local snapshots: postgres `f8b9ecc4`, configs `0d340b8e`.
- Offsite configs snapshot: `851630e7`.
- Grafana active alert count: `0`.

### B1 attempt — 2026-07-29

- All gauges advanced without rerunning the seed command: postgres
  `1785297736`, configs `1785297752`, offsite `1785297901`.
- Prometheus returned exactly one series for every advanced gauge.
- B1 failed repository verification. Voyager still contained only B0 snapshot
  `851630e7`; scheduled `offsite-push` logs referenced local snapshot parents
  and the new snapshots appeared only in the local repository.
- B1 also failed freshness verification for postgres. `postgres-dump` could
  not create `/backup/postgres.sql.tmp`, but `postgres-backup` subsequently
  snapshotted the previous dump and advanced its gauge.
- Root cause was Ofelia `job-exec` ownership: both jobs were labeled on
  `restic`, so their `.container` labels did not redirect execution.
- Servarr `#140` moved `postgres-dump` to `postgres` and offsite jobs to
  `restic-offsite`, added a regression contract, and deployed commit
  `6fc7ff7` through `desktop-nixos`.
- Manual post-deploy proof created a fresh dump, local postgres snapshot
  `44567ca1`, and Voyager offsite configs snapshot `68df59e6`.
- At that point, B1 still required a scheduled retry. The 2026-08-01 retry
  below proved the gauge and repository paths; only direct successful-job log
  correlation remains.

### Post-fix alert check — 2026-07-29 05:25 UTC

- The next scheduled cycle had not occurred. Current gauges remained postgres
  `1785301336`, configs `1785301353`, and offsite `1785301501`; Prometheus
  returned exactly one series for each.
- Grafana reported five active alerts: Argo CD `demo` unhealthy/out of sync,
  Discovery `/` below 15% free, Discovery `/home/erik/vault` below 15% free,
  a Discovery SSH authentication-failure burst, and a backup-rule
  `DatasourceError`.
- The backup alert was an evaluation defect, not evidence of stale backups:
  Grafana logged `vector cannot contain metrics with the same labelset` for
  rule `restic-kepler-backups-stale`, while the same Prometheus query returned
  one healthy value.
- Servarr `#141` replaced the backup expression with one scalar result and
  made the filesystem rule aggregate by stable mountpoint labels. GitOps `#21`
  removed `spec.replicas` from the KEDA-managed demo Deployment, stopping the
  Argo CD/KEDA reconciliation loop.
- Servarr `#142` excluded alert-query log feedback from the SSH failure rule
  and added the Loki healthcheck required by the monitoring systemd gate.
- After deployment, `demo` was Synced/Healthy, Loki was healthy,
  `podman-compose-monitoring.service` was active, and Grafana reported
  `active=0`.
- This check preceded the successful 2026-08-01 repository proof below.

### Operational alert record — 2026-07-29

- `homelab-iac-drift.service` fired because a committed short-lived GitHub App
  management token expired. The Discovery checkout also had a generated
  `.env.sops` modification that blocked its pre-plan fast-forward.
- The durable fix moved token rotation to runtime OpenBao state:
  `homelab-iac#42`, `desktop-nixos#133`, and `desktop-nixos#134`. The old
  checkout modification remains recoverable in stash
  `pre-vault-runtime-token`.
- The first post-deploy plan exposed two independent source/state problems:
  live AdGuard had lost the five IaC-declared rewrites, preventing the MinIO
  state endpoint and NetBird OIDC endpoint from resolving; imported
  `buzz-flake` state was absent from `main`, and `prevent_destroy` correctly
  blocked deletion.
- The declared rewrites were restored, `homelab-iac#40` was merged, and
  `docker-netbird-management.service` recovered. The final drift invocation
  completed all 28 units with exit `2`, which systemd accepts as success.
- The original drift and follow-on NetBird failed-unit alerts recovered.
  Remaining active warnings at handoff were Argo CD `demo` OutOfSync, a
  Voyager SSH login from `177.137.224.188`, and a Discovery SSH authentication
  failure burst. These are evidence for A0/security triage, not grounds for
  threshold tuning before the fixed seven-day review.

### B1 scheduled proof — 2026-08-01

- All three gauges advanced without invoking the seed recipe: postgres
  `1785550501`, configs `1785551402`, and offsite `1785560404`.
- Prometheus returned exactly one series for every metric.
- Fresh snapshots existed in the intended repositories: local postgres
  `7405f226`, local configs `fa12534d`, and Voyager offsite configs
  `b3449140`.
- The matching postgres dump was fresh at `2026-08-01T02:00:00Z` and 57,649
  bytes, proving the old dump was not reused.
- Historical successful Ofelia job logs had rotated from both container and
  journal retention. Because the gauges are written atomically only after
  Restic succeeds, repository and scheduler behavior are substantively
  proven. The stricter direct log-correlation requirement remains open for one
  future scheduled cycle.

## 5. A0 — capture the alert-history evidence

Run on 2026-08-01 or later. Use exactly the complete UTC window
`2026-07-25T00:00:00Z` through `2026-08-01T00:00:00Z`; do not include the
partial rollout period.

1. Export Grafana alert annotations through `/api/annotations` with
   `type=alert`, explicit `from`/`to` milliseconds, and a limit high enough to
   avoid truncation. Keep credentials inside the Discovery remote shell.
2. Save the raw JSON as local, gitignored evidence and record its SHA-256,
   window, Grafana version, and row count.
3. Group transitions by rule UID, alert name, instance, and state.
4. For each rule, record:
   - firing and recovery count;
   - shortest firing duration;
   - repeated transitions inside one hour;
   - firing during a documented deploy, reboot, or outage;
   - current state from `just grafana-alert-status`.
5. Check rules with zero transitions against current Prometheus data and their
   intended failure condition. Zero transitions alone is not a defect.

If the API result reaches the requested limit, split the same fixed window into
smaller intervals and deduplicate by annotation ID before analysis.

### A0 implementation record — 2026-08-01

- Captured the exact UTC window `2026-07-25T00:00:00Z` through
  `2026-08-01T00:00:00Z`: 1,365 rows from Grafana `13.1.0`, below the
  requested 10,000-row limit.
- Raw annotations SHA-256:
  `24a5af091aaba2ca1bf9e4e6941822bc5e80d7335aab23b046e6aa582782352b`.
  All-48-rule summary SHA-256:
  `c029d7179540091978aa5d23dd6345d346cdd556b9cb68d3efa9f5465180c879`.
- SSH failure bursts produced 37 completed episodes. The fixed-window Loki
  export found 2,342 genuine Vanguard failures from 198 source IPs; its
  SHA-256 is
  `a15b63e94866c66d0b5c963b45b8b0a260fbf216fb426c81fef8b7e1d457f8ec`.
- Systemd-unit, Alloy, Argo CD, container, and SSH-login alerts corresponded
  to real failures, maintenance, or security events and recovered.
- Eight rules had zero transitions. Their current Prometheus queries were
  healthy, so absence of firing was not treated as a defect.
- A0 found no evidence-backed threshold change. It did expose one SIEM parser
  defect and one inactive brute-force control, handled below.

## 6. A1 — apply only evidence-backed tuning

A rule qualifies for change only when A0 proves one of:

- repeated fire/recover churn from normal variance;
- delayed notification after the underlying condition already recovered;
- a query or label mismatch that prevents a known condition from firing;
- a threshold or `for` duration contradicted by the full observation window.

For each qualifying rule:

1. Write one failing contract in the existing Servarr alerting tests.
2. Make the smallest change in the existing provisioned rule.
3. Run the focused test, then Discovery's alerting/static contract suite.
4. Exercise the changed query against the local Grafana rig.
5. Deploy with the existing Servarr-to-Discovery workflow.
6. Force-fire the rule once using a reversible service/pod failure, observe the
   Discord notification and recovery, then restore service.

Do not tune healthy rules, add new infrastructure, or change several unrelated
thresholds in one patch. If A0 finds no defect, record “no tuning required”
and close this slice without a code change.

### A1 result — no threshold tuning required

- Servarr `#153` and `#154` fixed UniFi/Wazuh event-time parsing. The deployed
  scheduled job exported the real event epoch `1785620696`, and the UniFi SIEM
  silence alert recovered.
- Vanguard's Fail2ban jail was active but counted zero failures because NixOS
  OpenSSH logs use `_COMM=sshd-session`, absent from the jail's journal match.
  `desktop-nixos#145` added that existing native match. Deployed validation then
  found the Python journal binding loaded `systemd-minimal-libs`, which opened
  the journal but returned zero entries. `desktop-nixos#146` points only the
  Fail2ban service at the host's existing full `libsystemd`.
- Both fixes are deployed to Vanguard and Voyager. The daemons load the full
  library and hold live journal descriptors. Voyager immediately counted five
  real failures and banned `175.119.225.92`; key services are active and both
  hosts have zero failed units.
- The current laptop filesystem prediction followed a Nix build, with about
  100 GB and 19.7% free. It recovered as the six-hour regression window aged
  out, so no cleanup or tuning was required.
- Vanguard activation also exposed its PostgreSQL standby requesting WAL that
  the primary had already removed. Following the documented no-slot recovery,
  the stale 721 MB data directory was preserved, a fresh 658,789 kB
  `pg_basebackup` completed, streaming resumed, and deployment confirmed.
- Result: fix parser and prevention paths, retain the current Grafana
  thresholds.
- Final Grafana check: `active=0` after the expected deployment-login warning
  and laptop filesystem prediction recovered.

## 7. Deferred decision gates

| Gate | Trigger required before implementation | First action after admission |
|---|---|---|
| UniFi Poller | A WAN/client question that UniFi CEF, Wazuh, and current health checks cannot answer | Write the question and expected metric; only then create the manual read-only UniFi account |
| LiteLLM spend history | A named cost question current `litellm_*` metrics cannot answer | Prove the required answer exists in `LiteLLM_DailyUserSpend` or `DailyTeamSpend`, then add the read-only datasource/dashboard |
| SWAG per-vhost traffic | A named investigation or alert requiring per-vhost request data | Define the exact Loki query and retention need before adding parsing |
| k3s control-plane scrape | A dashboard panel or alert rule requiring apiserver, scheduler, or controller-manager metrics | Name the metric and consumer, then add only the required scrape target |
| Local btrfs snapshot metric | A decision that local snapshot failure must page centrally | Define the failure signal and stale window, then extend the existing textfile pattern |

Rejected at planning time: speculative accounts, dashboards, exporters,
datasources, scrape jobs, and parsers.

## 8. Embedded-etcd observation track

No CPU or storage change is planned.

1. Keep the existing etcd dashboard and alerts under observation.
2. On the next latency/leader incident, capture journals from before the event,
   etcd latency series, leader changes, host CPU pressure, and storage latency.
3. Change CPU or storage only when that evidence identifies a bottleneck and
   supplies a before/after measurement.

## 9. Completion

Close the continuation when:

- B0 and B1 prove all three Kepler backup paths;
- A0 is recorded and A1 is either deployed and force-fired or explicitly
  closed with no tuning required;
- every untriggered gate remains documented as deferred;
- no unexplained embedded-etcd incident requires follow-up.

Then move the proposal and this plan to the implemented record together and
update the proposal indexes. Deferred gates may be reopened as new proposals
only when their trigger exists.
