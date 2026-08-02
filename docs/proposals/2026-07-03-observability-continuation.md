# Observability continuation — alerting depth, coverage gaps, cleanups

**Status:** Implemented and closed
**Date:** 2026-07-03
**Completed:** 2026-08-02
**Audience:** Maintainers of `desktop-nixos` + `servarr` + `homelab-gitops`

**Scheduled evidence gate:** tune alert thresholds from Grafana history only
after the first complete seven-day observation window closes on 2026-07-31.
Do not tune from the partial rollout window.

**Shipped 2026-07-15:** embedded-etcd scrape + provisioned dashboard. All three
control-plane targets verified `up=1`; that work is no longer part of this
backlog.

**Shipped 2026-07-24:** the first k8s telemetry-health slice now alerts on
Alloy OOMs, restarts, readiness, sustained remote-write backlog/retries, and
missing etcd targets. The live retry incident was a temporary Discovery
Prometheus outage during stack recreation; retries now require a 5-minute
rolling increase sustained for 10 minutes, so recovered maintenance does not
page late. `servarr#109` passed 79 Discovery tests plus 30 subtests and was
deployed to Discovery.

**Shipped 2026-07-24:** k8s alerting depth is complete: node NotReady,
CrashLoopBackOff, deployment replicas unavailable, PVC Pending, job failure,
HPA saturation, Argo health/sync, and Alloy resilience.

**Shipped 2026-07-24:** AdGuard, cloudflared, and LiteLLM scrape-failure
alerts. Intentionally stoppable GPU and llama.cpp targets remain
dashboard-only.

**Shipped 2026-07-25:** compose-host observability now supports Docker
cAdvisor and rootless Podman exporter metrics with stable container identity,
container liveness/restart alerts, and dashboard coverage.

**Shipped 2026-07-25:** compose stdout uses journald on Discovery, Kepler, and
Orion and flows through host Alloy to Loki. Dead container-Alloy configs and
the stale `alloy-discovery` scrape were removed.

**Shipped 2026-07-25–28:** PostgreSQL exporters, AI-serving dashboard, repaired
Kepler backup-gauge jobs, missing-gauge detection, and telemetry storage
hardening landed in `servarr` (`#124`, `#125`, `#128`, `#129`, `#134`,
`#137`, `#138`, `#139`). The live B0 proof completed: local postgres/config
snapshots, the offsite config snapshot, all three gauges, single-series
Prometheus results, and normal Grafana evaluation were verified. The first B1
attempt on 2026-07-29 failed: scheduled gauges advanced, but the offsite job
wrote into the local repository and the postgres dump job lacked its output
directory. Servarr `#140` corrected the Ofelia job ownership and passed manual
repository proof. The 2026-08-01 scheduled retry proved all three intended
repositories. Central Loki retained the next cycle's successful Ofelia logs,
closing the final direct-correlation gate on 2026-08-02.

**Shipped 2026-07-25:** Kepler runs the independent Discovery dead-man probe.
Its module and host contract are tested in `desktop-nixos`.

**Shipped 2026-07-29:** Discovery's `homelab-iac-drift` check now refreshes
the short-lived GitHub App management token at runtime. OAuth client and
refresh inputs render from OpenBao; rotated access and refresh tokens are
written atomically to a dedicated, narrowly writable Vault path instead of
committed to `.env.sops`. `homelab-iac#42`, `desktop-nixos#133`, and the
invocation correction in `desktop-nixos#134` were merged and deployed.
`homelab-iac#40` aligned the imported `buzz-flake` state with source. The live
unit completed all 28 plans with expected drift exit `2`, systemd recorded
`Result=success`, and the original failed-unit Grafana alert recovered.

**Shipped 2026-08-01:** the exact seven-day A0 alert-history review completed.
It found no threshold defect that justified tuning. Instead, live triage fixed
two root causes: UniFi/Wazuh event-time parsing in Servarr `#153` and `#154`,
and Fail2ban journal ingestion in `desktop-nixos#145` and `#146`. The UniFi
silence alert recovered after a real scheduled event exported the correct
epoch. Fail2ban now reads the full journal on Vanguard and Voyager; Voyager
immediately counted five real failures and banned one source.

**Shipped 2026-08-02:** the next scheduled Kepler cycle correlated all three
successful Ofelia completion lines with their exact gauges and Restic
snapshots. Prometheus returned exactly three series and the provisioned stale
rule expression evaluated to `0`. Both mandatory slices are complete.

## Deferred trigger gates

1. Decide whether UniFi Poller adds value beyond UniFi CEF/Wazuh before
   creating a read-only UniFi account.
2. Add LiteLLM historical-spend reporting only if the current metrics cannot
   answer a concrete cost question.
3. Add SWAG per-vhost traffic visibility only with a named investigation or
   alert use case.
4. Keep Kubernetes apiserver/scheduler/controller-manager scraping deferred
   until a dashboard or rule requires it.
5. Meter local btrfs snapshots only if their failure needs central paging.
6. Continue observing embedded-etcd latency; collect pre-incident journals
   before changing CPU or storage.

These items create no implementation work until their named trigger exists;
reopen them as narrow proposals only when triggered.

## Context

The 2026-06-29 fleet-monitoring RFC shipped: 15 provisioned dashboards, the
scrape wave (adguard, cloudflared, litellm, GPU ×2 vendors, tailscale,
kubelet volume stats, Argo CD health), tuned host alerting, and four
pipeline fixes. Follow-up alerting and coverage work shipped in July and the
final operational evidence gate passed in August. Optional coverage remains
trigger-based so this record can stay closed.

## A. Alerting depth (highest value — no new infra)

1. **k8s alert rules — shipped.** KSM, kubelet cAdvisor, Argo CD, etcd, and
   Alloy health rules are file-provisioned with windows that tolerate
   remote-write lag.
2. **AdGuard down — shipped.** `up{job="adguard"}` pages after five minutes.
3. **New-scrape liveness rules — shipped.** Cloudflared and LiteLLM alert;
   intentionally stoppable GPU/llama.cpp targets remain dashboard-only.
4. **Alert-history tuning round 2 — completed 2026-08-01.** The exact fixed
   seven-day annotations window was captured and all 48 rules reviewed. No
   threshold change was justified; the actionable findings were ingestion and
   prevention defects fixed at their sources.

## B. Coverage gaps (need new components or upstream fixes)

1. **Compose container observability — shipped.** Discovery uses cAdvisor;
   Kepler and Orion use `prometheus-podman-exporter`. Dashboard and alert
   queries support both metric families.
2. **Compose container logs → Loki — shipped.** Compose uses journald and the
   existing host Alloy path. Dead container-Alloy configs were deleted.
3. **unpoller — decision gate.** UniFi CEF already reaches Wazuh. Add a
   read-only UniFi Poller account and workload only if metrics answer a
   remaining WAN/client question that CEF and current health checks do not.
4. **postgres-exporter — shipped in `servarr#124`.** Discovery and Kepler
   infra stacks export metrics and Prometheus scrapes both targets.
5. **LiteLLM spend history** — live `litellm_*` metrics start at enable
   time; retroactive money panels come from postgres
   (`LiteLLM_DailyUserSpend` / `DailyTeamSpend`). Add a read-only PG role
   (`provision-db.sql` pattern) + a file-provisioned postgres datasource +
   a spend dashboard. Explicitly rejected during evaluation: sql_exporter
   (no timestamped history), Infinity/JSON endpoints
   (`/global/spend/report` is enterprise-gated), Langfuse→Prometheus
   (upstream declined the endpoint).
6. **AI-serving dashboard — shipped in `servarr#125`.** It covers LiteLLM,
   llama.cpp, NVIDIA, and AMD DRM metrics.
7. **Backup gauges — code and B0 live proof shipped.** Kepler emits atomic
   gauges and Grafana alerts when any expected gauge is absent or stale.
   On 2026-07-28 the local postgres/config snapshots and offsite config
   snapshot completed, Prometheus returned exactly one series per gauge, and
   Grafana had no active backup alert. B1 on 2026-07-29 exposed false-success
   scheduled paths: offsite snapshots landed locally, while postgres backup
   reused a stale dump after `/backup/postgres.sql.tmp` creation failed.
   Servarr `#140` moved each Ofelia `job-exec` label to its actual target
   container. Manual proof created local postgres snapshot `44567ca1` and
   Voyager configs snapshot `68df59e6`. The 2026-08-01 B1 retry advanced all
   three gauges without seeding and proved fresh snapshots in the intended
   local and offsite repositories. Historical successful Ofelia logs had
   rotated, so one future scheduled cycle still needs strict log correlation.
   Btrfs snapshots remain intentionally unmetered.
8. **swag / reverse-proxy traffic** — stub_status + nginx-exporter is coarse.
   Journald transport now exists; add per-vhost parsing only for a named
   investigation or alert.
9. **k3s control-plane scrape** (apiserver/scheduler/CM) — still absent;
   defer until a dashboard or rule actually needs it (KSM covers workload
   health).

## C. Incidents to close out (from the 2026-07-03 deploy)

1. **k3s pod restarts — diagnosed.** Current evidence matches joint guest
   startup after Kepler host boots, not independent periodic guest crashes.
   Embedded-etcd slow-disk/leader warnings remain observation evidence.
2. **Discovery found powered off mid-deploy** (2026-07-03) — cause
   unconfirmed. WOL from kepler works (`64:51:06:1a:f8:1a`; runbook in
   memory). If it recurs unexplained: check PSU/BIOS power settings and
   consider a `wol`-on-boot systemd timer on kepler as poor-man's
   auto-recovery. Ties into the deferred cross-host liveness ping below.
3. **Cross-host liveness ping — shipped.** Kepler probes Discovery ingress and
   uses an independent SOPS-managed Discord webhook after consecutive
   failures.

## D. Cleanups

- Stale `alloy-discovery` scrape removed.
- Four dead servarr `config/alloy/config.alloy` files deleted.
- Stale `n8n` scrape removed; no current Prometheus target exists.
- `llamacpp-gemma-vl` target stays down while the `vision` compose profile
  is off — already commented in the scrape config; revisit if the profile
  becomes long-lived.

## Verify (per item)

Same discipline as the parent RFC: every new rule force-fired once
(stop the service / kill the pod) and observed in Discord; every new
dashboard panel exercised against live data (the local Grafana rig
pattern: ephemeral 12.3.5 container, pinned datasource uids, sweep all
targets via `/api/ds/query`) before `pull-servarr discovery`.

## Implementation record — backup B0

- `homelab-iac#41`: allowed Kepler to reach Voyager's Restic receiver.
- `desktop-nixos#132`: made Servarr pulls always refresh decrypted compose
  environment files; permanently activated on Voyager on 2026-07-29.
- `servarr#137`, `#138`, `#139`: added tailnet DNS, synchronized the receiver
  credential, and used the user-prefixed path required by
  `rest-server --private-repos`.
- B0 gauges: postgres `1785282679`, configs `1785282680`, offsite
  `1785282780`.
- B0 snapshots: local postgres `f8b9ecc4`, local configs `0d340b8e`, offsite
  configs `851630e7`.
- Prometheus returned one series for each exact metric; Grafana active alert
  count was `0`.
- B1 attempt on 2026-07-29 advanced the gauges to postgres `1785297736`,
  configs `1785297752`, and offsite `1785297901`; Prometheus still returned
  exactly one series each.
- B1 did not pass: Voyager still contained only B0 snapshot `851630e7`;
  scheduled offsite jobs used local snapshot parents and wrote locally.
  `postgres-dump` also failed because `/backup` did not exist, so subsequent
  postgres snapshots captured the previous dump.
- Servarr `#140` fixed the shared cause by moving Ofelia `job-exec` labels
  from `restic` to the `postgres` and `restic-offsite` target containers. Its
  regression test and compose renders passed; commit `6fc7ff7` is deployed.
- Manual post-deploy verification created a fresh postgres dump, local
  postgres snapshot `44567ca1`, and offsite configs snapshot `68df59e6`.
- At `2026-07-29 05:25 UTC`, Prometheus still returned one healthy series for
  each gauge. Grafana had four genuine warnings: Argo CD `demo` unhealthy/out
  of sync, low free space on Discovery `/` and `/home/erik/vault`, and a
  Discovery SSH authentication-failure burst.
- Grafana also exposed a `DatasourceError` in
  `restic-kepler-backups-stale`: `vector cannot contain metrics with the same
  labelset`. The underlying Prometheus query returned one healthy value, so
  this is an alert-query defect rather than backup-freshness evidence.
- Servarr `#141` fixed the backup and filesystem query shapes; GitOps `#21`
  removed the KEDA/Argo CD `spec.replicas` ownership conflict. Servarr `#142`
  filtered SSH alert-query feedback and added the missing Loki container
  healthcheck required by the monitoring systemd gate.
- Live verification after deployment: Argo CD `demo` Synced/Healthy, Loki
  healthy, monitoring systemd unit active, and Grafana `active=0`.
- The remaining backup gate closed on 2026-08-02 with direct Ofelia log,
  gauge, and snapshot correlation.

## Implementation record — B1 scheduled repository proof

- On 2026-08-01 all gauges advanced without rerunning the seed command:
  postgres `1785550501`, configs `1785551402`, and offsite `1785560404`.
- Prometheus returned exactly one series for each exact metric.
- The matching fresh snapshots were local postgres `7405f226`, local configs
  `fa12534d`, and offsite configs `b3449140` in Voyager's offsite repository.
- The postgres dump was fresh (`2026-08-01T02:00:00Z`, 57,649 bytes), excluding
  reuse of the stale dump exposed by the first B1 attempt.
- Old successful Ofelia execution logs were no longer retained. Gauge files
  are written only after successful Restic commands, but the plan's stricter
  direct log-correlation clause remains open for the next scheduled cycle.

## Implementation record — B1 direct log correlation

- Central Loki retained the 2026-08-02 Ofelia completion lines after Kepler's
  local container log buffer rotated: `postgres-backup` finished successfully
  at `02:15:02Z`, `config-backup` at `02:30:01Z`, and `offsite-push` at
  `05:00:14Z`.
- Their gauges were respectively `1785636902`, `1785637801`, and `1785646814`.
  Prometheus returned exactly three series with those values.
- Matching snapshots were local postgres `d7b48636` at `02:15:00Z`, local
  configs `13e1f842` at `02:30:00Z`, and offsite configs `11182083` at
  `05:00:00Z`. The postgres dump was fresh at `02:00:00Z` and 57,649 bytes.
- The provisioned stale-rule PromQL evaluated to `0`. B1 and the proposal are
  complete; no code or threshold change was required.

## Implementation record — A0 alert review and remediation

- Fixed UTC window: `2026-07-25T00:00:00Z` through
  `2026-08-01T00:00:00Z`; Grafana `13.1.0`; 1,365 annotations, below the
  requested 10,000-row limit.
- Raw annotations SHA-256:
  `24a5af091aaba2ca1bf9e4e6941822bc5e80d7335aab23b046e6aa582782352b`.
  The 48-rule summary SHA-256 is
  `c029d7179540091978aa5d23dd6345d346cdd556b9cb68d3efa9f5465180c879`.
- The largest actionable signal was 37 SSH-failure episodes. Vanguard alone
  received 2,342 genuine failures from 198 source IPs, while Fail2ban reported
  none. `desktop-nixos#145` added current OpenSSH's `_COMM=sshd-session` match.
  Live validation then found Nix's `systemd-minimal-libs` opened the journal but
  returned zero entries; `desktop-nixos#146` points only `fail2ban.service` at
  the host's existing full `libsystemd`. Both fixes are deployed to Vanguard
  and Voyager. Both daemons hold live journal file descriptors, Voyager counted
  five real failures and banned `175.119.225.92`, all key services are active,
  and both hosts have zero failed units.
- UniFi SIEM silence was a parser defect, not a threshold defect. Servarr
  `#153` and `#154` select the top-level Wazuh event epoch rather than a
  fractional timestamp or nested agent ID. A scheduled job exported
  `1785620696`, and the alert recovered.
- Systemd-unit, Alloy, Argo CD, and container alerts corresponded to real
  incidents and recovered. Eight zero-transition rules were checked against
  current Prometheus data and were healthy.
- A1 result: **no threshold tuning required**. Root causes were fixed instead.
  A transient laptop filesystem prediction after a Nix build has about 100 GB
  free; it recovered as the six-hour regression window aged out.
- Vanguard deployment exposed an unrelated stale-WAL PostgreSQL standby. This
  is the documented no-replication-slot failure mode: the stale data directory
  was moved aside, a fresh 658,789 kB `pg_basebackup` completed, streaming WAL
  resumed, and deployment then confirmed with no failed units.
- Final Grafana check: `active=0` after the expected deployment-login warning
  and laptop filesystem prediction recovered.

## Links

- [Execution plan](2026-07-03-observability-continuation-execution-plan.md)
- Parent (closed record): `implemented/2026-06-29-grafana-fleet-monitoring.md`
- Related: `implemented/2026-06-20-telemetry-hardening.md`,
  `reference/kepler-k3s-platform-status.md`
