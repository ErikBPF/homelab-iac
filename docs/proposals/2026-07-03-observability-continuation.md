# Observability continuation — alerting depth, coverage gaps, cleanups

**Status:** Proposed — backlog carried over from
`implemented/2026-06-29-grafana-fleet-monitoring.md` (shipped 2026-07-03)
plus new items surfaced during that deploy. Nothing here is scheduled;
items are independent and ranked inside each section.
**Date:** 2026-07-03
**Audience:** Maintainers of `desktop-nixos` + `servarr` + `homelab-gitops`

**Shipped 2026-07-15:** embedded-etcd scrape + provisioned dashboard. All three
control-plane targets verified `up=1`; that work is no longer part of this
backlog.

## Context

The 2026-06-29 fleet-monitoring RFC shipped: 15 provisioned dashboards, the
scrape wave (adguard, cloudflared, litellm, GPU ×2 vendors, tailscale,
kubelet volume stats, Argo CD health), tuned host alerting, and four
pipeline fixes. What remains is **alerting depth** (dashboards now far
outrun alert rules), a handful of **coverage gaps** that need new
components, and **cleanups** the deploy exposed. This RFC is the container
for that backlog so the implemented doc can stay a closed record.

## A. Alerting depth (highest value — no new infra)

1. **k8s alert rules** — the biggest gap. KSM + kubelet cAdvisor + Argo CD
   metrics all flow; zero k8s rules exist. Port the fitting subset of the
   kube-prometheus set as file-provisioned Grafana rules (`rules.yaml`,
   new `k8s` group): node `NotReady`, `CrashLoopBackOff`
   (`max_over_time(kube_pod_container_status_waiting_reason{reason=
   "CrashLoopBackOff"}[5m]) >= 1`), deployment replicas unavailable, PVC
   `Pending`, job failed, HPA at max. Plus the GitOps rule the original RFC
   couldn't have: `argocd_app_info{health_status!="Healthy"}` /
   `sync_status!="Synced"` sustained 15m. Mind the 5–15 min remote_write
   lag (≥15m windows) and the `deleteRules` tombstone gotcha.
2. **AdGuard down = whole-LAN DNS outage** — highest-value single alert
   available today (`up{job="adguard"} == 0` or `adguard_running == 0`,
   short `for:`). The exporter is live; the rule was never written.
3. **New-scrape liveness rules** — cloudflared tunnel down (public ingress
   dead), litellm scrape down, nvidia/llama.cpp down *only if* the AI
   stacks' intentional stop-windows (VRAM freeing, gaming) get an
   inhibition story — otherwise these stay dashboard-only by design.
4. **Alert-history tuning round 2** — repeat the annotations-API review
   (7d window) a week after the k8s rules land; the first round caught 3
   flappers and one never-fires bug.

## B. Coverage gaps (need new components or upstream fixes)

1. **cadvisor name-label gap on compose hosts** (carried over, still the
   real Phase-2 blocker): rootless podman `/run/user/1000` is 0700 so the
   servarr-side Alloy cadvisor can't resolve container names on
   kepler/orion, and discovery's docker emits none either. Until fixed, the
   tombstoned `container-critical-down` / `container-restart-storm` rules
   stay dead and compose dashboards stay nameless. Candidate fixes:
   podman socket group/ACL for the alloy user, or scraping podman's own
   `--metrics` socket instead of cadvisor.
2. **Compose container logs → Loki** — the deploy audit proved only
   journal + k8s streams exist; container stdout never reaches Loki. The
   four `machines/*/config/alloy/config.alloy` files in servarr are dead
   (no alloy container exists; they target never-deployed Mimir) — delete
   them, then decide the real path: journald log driver for
   podman/docker (rides the existing journal pipeline, zero new
   components — likely winner) vs a host-side `loki.source.docker` block
   in the NixOS Alloy.
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
7. **Backup gauges for compose restic jobs** — kepler/orion ofelia restic
   jobs emit nothing; extend the textfile dead-man pattern
   (`<job>_last_success_seconds`) so the backups dashboard's "unmetered"
   list empties. Check btrfs-snapshot metrics while there.
8. **swag / reverse-proxy traffic** — stub_status + nginx-exporter is
   coarse; the richer per-vhost board wants SWAG access logs, which lands
   inside B.2's logs decision. Do B.2 first.
9. **k3s control-plane scrape** (apiserver/scheduler/CM) — still absent;
   defer until a dashboard or rule actually needs it (KSM covers workload
   health).

## C. Incidents to close out (from the 2026-07-03 deploy)

1. **k3s pods restart every few hours** (exit 255, reason Unknown; 16–32
   restarts/12d — the microvm nodes themselves appear to reboot).
   Diagnose via the now-labeled journal streams from the microvms and
   `kube_node_*`. Not urgent (workloads recover) but it pollutes
   restart-based alerting.
2. **Discovery found powered off mid-deploy** (2026-07-03) — cause
   unconfirmed. WOL from kepler works (`64:51:06:1a:f8:1a`; runbook in
   memory). If it recurs unexplained: check PSU/BIOS power settings and
   consider a `wol`-on-boot systemd timer on kepler as poor-man's
   auto-recovery. Ties into the deferred cross-host liveness ping below.
3. **Cross-host liveness ping** (deferred in the original RFC, and the
   power-off incident proved the SPOF is real): a peer (kepler) watches
   discovery's heartbeat and pushes a Discord webhook directly on
   silence — the one alert path that must not live on discovery.

## D. Cleanups

- Drop the stale `alloy-discovery` scrape job (localhost:12345 never
  worked from inside the container) or fix it to scrape the host alloy.
- Delete the four dead servarr `config/alloy/config.alloy` files (part of
  B.2).
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
