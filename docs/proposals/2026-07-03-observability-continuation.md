# Observability continuation — alerting depth, coverage gaps, cleanups

**Status:** Partially implemented — backlog carried over from
`implemented/2026-06-29-grafana-fleet-monitoring.md` (shipped 2026-07-03)
plus new items surfaced during that deploy. Nothing here is scheduled;
items are independent and ranked inside each section.
**Date:** 2026-07-03

**Scheduled evidence gate:** tune alert thresholds from Grafana history only
after the first complete seven-day observation window closes on 2026-07-31.
Do not tune from the partial rollout window.
**Audience:** Maintainers of `desktop-nixos` + `servarr` + `homelab-gitops`

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
HPA saturation, Argo health/sync, and Alloy resilience. `servarr#111` passed
83 Discovery tests plus 30 subtests and was deployed to Discovery.

**Shipped 2026-07-24:** AdGuard scrape failure now pages as critical after five
minutes. `servarr#112` passed 84 Discovery tests plus 30 subtests and was
deployed to Discovery.

**Shipped 2026-07-24:** cloudflared and LiteLLM scrape failures now alert after
ten minutes. GPU and llama.cpp targets remain dashboard-only because their
stacks are intentionally stopped. `servarr#113` passed 85 Discovery tests plus
30 subtests and was deployed to Discovery.

**Shipped 2026-07-25:** compose-host container observability.
Discovery's host Alloy points cAdvisor at Docker's embedded containerd socket
(77 named containers currently verified). Kepler and Orion run a pinned
`prometheus-podman-exporter` with enhanced labels, scraped by unprivileged host
Alloy (11 and 5 named containers verified). Their old privileged cAdvisor path
was removed (`servarr#115`, `#116`; `desktop-nixos#103`, `#105`). The Homelab
Overview dashboard and both container alerts now consume the mixed metric
contract; controlled synthetic instances force-fired the warning and critical
notification paths, then cleared after a pause/unpause state reset
(`servarr#117`). The fleet verifier follows each host's native exporter
(`desktop-nixos#108`).

**Shipped 2026-07-25:** compose stdout uses the
journald driver on Discovery, Kepler, and Orion, so the existing host Alloy
journal pipeline ships it to Loki. The four never-deployed container-Alloy
configs and the stale `alloy-discovery` scrape were removed. Kepler's local
PostgreSQL and config backups now publish atomic textfile last-success gauges;
the offsite gauge remains absent while Voyager is unreachable, which the
30-hour Grafana dead-man rule now detects. Orion's dormant repository-check
metric and alert were removed because Orion has no remaining payload backup.

## Context

The 2026-06-29 fleet-monitoring RFC shipped: 15 provisioned dashboards, the
scrape wave (adguard, cloudflared, litellm, GPU ×2 vendors, tailscale,
kubelet volume stats, Argo CD health), tuned host alerting, and four
pipeline fixes. What remains is **alerting depth** (dashboards now far
outrun alert rules), a handful of **coverage gaps** that need new
components, and **cleanups** the deploy exposed. This RFC is the container
for that backlog so the implemented doc can stay a closed record.

## A. Alerting depth (highest value — no new infra)

1. **k8s alert rules — shipped 2026-07-24.** KSM, kubelet cAdvisor, Argo CD,
   etcd, and Alloy health rules are file-provisioned with 15-minute workload
   windows to tolerate remote-write lag.
2. **AdGuard down — shipped 2026-07-24.** The existing
   `up{job="adguard"}` signal pages as critical after five minutes.
3. **New-scrape liveness rules — shipped 2026-07-24.** Always-on cloudflared
   and LiteLLM targets alert after ten minutes. Intentionally stoppable
   nvidia/llama.cpp targets remain dashboard-only until an inhibition story
   exists.
4. **Alert-history tuning round 2** — repeat the annotations-API review
   (7d window) a week after the k8s rules land; the first round caught 3
   flappers and one never-fires bug.

## B. Coverage gaps (need new components or upstream fixes)

1. **Compose container observability — shipped 2026-07-25.** Discovery keeps
   embedded cAdvisor for Docker; Kepler/Orion use
   `prometheus-podman-exporter` because cAdvisor cannot inspect rootless Podman
   storage. Dashboard queries, the machine selector, critical-container
   liveness, and restart-storm detection support both metric families. Restart
   detection uses `changes()` on start-time gauges rather than the former
   invalid `increase()` calculation.
2. **Compose container logs → Loki — shipped 2026-07-25.**
   Discovery/Kepler/Orion compose services use journald and ride the
   existing host Alloy journal pipeline. The four dead container-Alloy configs
   were deleted. Voyager keeps its local JSON logging because it intentionally
   has no Alloy.
3. **unpoller** (UniFi/UDM) — needs a **manual read-only UniFi OS
   account** first (not IaC-able; document the step in homelab-iac's
   README). Then: `ghcr.io/unpoller/unpoller` in the discovery monitoring
   stack, scrape job, and commit dashboards 11313 (gateway) + 11315
   (clients) as provisioned JSON. Unlocks WAN edge + the ~20 non-fleet
   LAN devices.
4. **postgres-exporter** on discovery + kepler infra stacks (covers
   litellm/langfuse/n8n/healthchecks DBs): one
   `prometheuscommunity/postgres-exporter` sidecar per `infra.yml`,
   creds from the existing `.env`.
5. **LiteLLM spend history** — live `litellm_*` metrics start at enable
   time; retroactive money panels come from postgres
   (`LiteLLM_DailyUserSpend` / `DailyTeamSpend`). Add a read-only PG role
   (`provision-db.sql` pattern) + a file-provisioned postgres datasource +
   a spend dashboard. Explicitly rejected during evaluation: sql_exporter
   (no timestamped history), Infinity/JSON endpoints
   (`/global/spend/report` is enterprise-gated), Langfuse→Prometheus
   (upstream declined the endpoint).
6. **AI-serving dashboard** — `llamacpp:*` (tokens/s, KV cache, slots),
   `nvidia_smi_*`, `node_drm_*`, `litellm_*` all flow now; no board unites
   them. Include a GPU-temp caveat: orion AMD temps stay hwmon-excluded
   (SMU-wedge guard) and the drm collector reads a *different* amdgpu
   sysfs path — first suspect if a wedge recurs.
7. **Backup gauges for compose restic jobs — partially shipped 2026-07-25.**
   Kepler's active sync stack atomically publishes
   `<job>_last_success_seconds`; a real PostgreSQL dump and 1.37 GiB config
   snapshot seeded the two local gauges. Repository paths were rotated while
   preserving repositories encrypted with the retired key. Voyager remained
   unreachable, so the offsite job did not fabricate a success gauge; the
   Grafana rule alerts when any of the three gauges is missing or older than
   30h. Orion's dormant repository-check metric and 9-day alert were removed:
   it has no payload backup since Hermes moved to Discovery. Btrfs snapshots
   remain local-only and unmetered.
8. **swag / reverse-proxy traffic** — stub_status + nginx-exporter is
   coarse; the richer per-vhost board wants SWAG access logs, which lands
   inside B.2's logs decision. Do B.2 first.
9. **k3s control-plane scrape** (apiserver/scheduler/CM) — still absent;
   defer until a dashboard or rule actually needs it (KSM covers workload
   health).

## C. Incidents to close out (from the 2026-07-03 deploy)

1. **k3s pod restarts — diagnosed 2026-07-25.** Current evidence shows all
   three guests starting together after a Kepler host boot, not independent
   periodic guest crashes. The actionable signal is embedded-etcd latency:
   repeated 100–500ms requests and late-heartbeat warnings explicitly naming
   slow disk/leader overload on the ZFS-backed control plane. Keep observing;
   do not add a speculative VM restart fix. If alerts recur without a host
   boot, capture the preceding guest/host journal before changing CPU/storage.
2. **Discovery found powered off mid-deploy** (2026-07-03) — cause
   unconfirmed. WOL from kepler works (`64:51:06:1a:f8:1a`; runbook in
   memory). If it recurs unexplained: check PSU/BIOS power settings and
   consider a `wol`-on-boot systemd timer on kepler as poor-man's
   auto-recovery. Ties into the deferred cross-host liveness ping below.
3. **Cross-host liveness ping — shipped on Kepler 2026-07-25.** Vanguard has
   the stronger offsite role configured, but its
   tailnet SSH endpoint was unreachable during verification. Kepler now runs
   the same small timer as an active fallback: it probes PocketID through
   Discovery's public ingress every five minutes and, after three failures,
   posts directly through the independent SOPS-managed Discord webhook.
   The timer was deployed and Kepler post-switch verification reported no
   failed units.

## D. Cleanups

- Stale `alloy-discovery` scrape removed 2026-07-25.
- Four dead servarr `config/alloy/config.alloy` files deleted 2026-07-25.
- `n8n` scrape target is permanently down — the kepler `ai-usage` stack is
  authored but not deployed. Either deploy the stack or comment the job
  out until it exists.
- `llamacpp-gemma-vl` target stays down while the `vision` compose profile
  is off — already commented in the scrape config; revisit if the profile
  becomes long-lived.
- Local test-rig teardown: `podman rm -f grafana-dash-test` on the laptop
  when done comparing (rig pattern is recorded in project memory).

## Verify (per item)

Same discipline as the parent RFC: every new rule force-fired once
(stop the service / kill the pod) and observed in Discord; every new
dashboard panel exercised against live data (the local Grafana rig
pattern: ephemeral 12.3.5 container, pinned datasource uids, sweep all
targets via `/api/ds/query`) before `pull-servarr discovery`.

## Links

- Parent (closed record): `implemented/2026-06-29-grafana-fleet-monitoring.md`
- Related: `implemented/2026-06-20-telemetry-hardening.md`,
  `reference/kepler-k3s-platform-status.md`
