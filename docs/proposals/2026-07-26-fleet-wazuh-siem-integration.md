# Fleet Wazuh SIEM integration

**Status:** In progress; fresh UniFi CEF-to-index delivery and indexer disk
watermarks are deployed on Kepler; snapshot/restore proof remains open
**Date:** 2026-07-26
**Owners:** `servarr` (Wazuh runtime and rules), `desktop-nixos` (host agents
and host security signals), `homelab-gitops` (Kubernetes security signals),
`homelab-iac` (network reachability and external control planes), and
`homelab` (cross-repository policy and acceptance)

## Goal

Connect the useful security signals from the whole fleet to Wazuh without
turning Wazuh into a second copy of Loki or adding agents to repositories that
do not own a runtime.

The target answers these questions:

- Who attempted or completed authentication, from where, and on which host?
- Did a privileged identity, authentication policy, executable, or protected
  configuration change?
- Did UniFi, Cloudflare, a firewall, or an overlay report suspicious traffic
  or an administrative change?
- Did a host, container substrate, Kubernetes control plane, Home Assistant,
  printer, or AI workload lose its security controls?
- Is the evidence pipeline itself alive, retained, backed up, and testable?

## Current foundation

The following exists on the default branches and live Kepler deployment:

- Wazuh 4.14.6 single-node indexer, manager, and dashboard with digest-pinned
  images, TLS, secret-backed authentication, health checks, persistent volumes,
  and a LAN-bound dashboard.
- NixOS firewall ingress on Kepler for agent events (`1514/tcp`), enrollment
  (`1515/tcp`), and rootless UniFi syslog (`5514/udp`).
- UniFi CEF destination `192.168.10.230:5514`; Network and Protect categories
  are enabled and decoder coverage includes OS, Network, and Protect products.
- Rootless Podman forwarding accepted through its `10.89.0.0/24` internal
  network while the host firewall remains the external LAN boundary.
- JSON retention for all received Wazuh events; alert-only indexing remains the
  current Filebeat behavior.
- UniFi CEF decoding with structured source/destination IP, user, action,
  device, category, reason, and message fields:
  - baseline events: rule `100100`, level 3;
  - security keywords: rule `100101`, level 7;
  - CEF severity 4–10: rule `100102`, level 7.
- Live verification of the UniFi test event from `ISS`, model `UDMPRO`,
  UniFi OS `5.1.19`, reporting device IP `192.168.50.57`; current Network CEF
  reports the gateway as `192.168.1.1`, so the older address remains inventory
  evidence to reconcile rather than an allowlist input.
- A Prometheus textfile gauge records the latest received UniFi CEF timestamp;
  Grafana warns after 26 hours of silence and treats missing data as failure.
- The Kepler compose host configuration includes the `security` stack so Wazuh
  returns after host reboot.
- Live decoder fixes in `servarr` PRs #163, #164, and #165 account for Wazuh's
  syslog pre-decoder and split parent/header/extension extraction correctly.
- A fresh archived Network threat event on 2026-08-02 decoded product,
  signature, event, severity, action, source/destination, and device fields and
  fired warning rule `100101` in `wazuh-logtest`.
- Fresh Protect motion and smart-detection events traversed UDP, the Wazuh raw
  archive, rule `100100`, Filebeat, and the `wazuh-alerts-*` index. The receiver
  gauge advanced and the Grafana silence alert recovered.
- OpenSearch disk allocation protection is enabled with explicit 80% low, 85%
  high, and 90% flood-stage watermarks (`servarr` PR #166). The live cluster is
  green with zero unassigned shards.

Measured retention evidence on 2026-08-02:

- retained data from 2026-07-26 through 2026-08-02 contains Network and Protect
  CEF; 2026-07-31 and 2026-08-01 each produced about 52 MB of raw JSON, and
  2026-08-01 contained 1,279 CEF events;
- daily archive compression reduced a 51.9 MB raw file to 2.4 MB;
- the indexer uses 4.7 MB on a 1.1 TB pool currently at 9% usage;
- no OpenSearch snapshot repository or index-state-management policy exists.
  Restic sees the live index data under `/config`, but that is not accepted as
  a consistent OpenSearch backup. Snapshot creation and isolated restore proof
  remain the next server gate.

Existing complementary telemetry:

- NixOS journals flow through Alloy or lightweight Vector to Loki.
- Host and Kubernetes health metrics flow to Prometheus/Grafana.
- Auditd watches PAM, password/group databases, sudoers, and sudo logs on
  capable NixOS hosts.
- Grafana owns existing runtime security alarms and Discord routing.
- Every sister repository has a source/dependency security notification path;
  those GitHub findings remain outside Wazuh.

## Decisions

### D1 — Wazuh is the security plane; Loki remains the general log plane

Do not send every fleet journal and container log to both systems.

- Wazuh receives authentication, audit, integrity, malware, policy, network
  security, and security-control health events.
- Loki retains broad journals, application troubleshooting logs, and high-volume
  container output.
- Prometheus/Grafana retains health, absence, rate, and dead-man detection.
- GitHub remains authoritative for source, dependency, provenance, and secret
  scanning findings.

Cross-links may point from a Wazuh alert to a Grafana/Loki investigation view.
No new event bus or normalization service is justified.

### D2 — Connect deployed runtimes, not source repositories

Package, skill, configuration, and firmware repositories do not receive a
Wazuh agent. Their runtime host, Kubernetes namespace, network edge, or CI
system supplies the signal.

### D3 — Prefer agents for capable hosts and syslog for appliances

- NixOS servers/workstations: Wazuh agent managed by one reusable
  `desktop-nixos` module.
- Resource-constrained hosts: measure agent cost first; retain the existing
  Vector/Loki path if the agent exceeds the budget.
- UniFi and other appliances: CEF/syslog into the manager.
- Kubernetes: collect cluster audit/security sources once; do not run an agent
  in every pod.
- Firmware-only devices: observe them at UniFi, DNS, Cloudflare, reverse proxy,
  and application gateways.

### D4 — Enrollment and transport use the overlay where possible

Host agents connect to Kepler over Tailscale, with stable agent names matching
`desktop-nixos` fleet names.

- `1514/tcp`: fleet agent events.
- `1515/tcp`: enrollment, temporarily open only during controlled enrollment
  or restricted to named fleet sources.
- `5514/udp`: LAN appliance syslog only; never port-forwarded.
- `5601/tcp`: dashboard remains LAN-bound until an authenticated reverse-proxy
  decision exists.

Do not rely on the Wazuh event `location` for appliance attribution under
rootless Podman: it records the Podman forwarding address. Extract and retain
CEF device IP, MAC, model, name, source, destination, user, action, and message.

### D5 — Keep raw security events, but measure the cost

Keep `logall_json=yes` and `logall=no` to avoid duplicate text and JSON copies.
Raw archives remain local initially; alerts are indexed.

Before indexing all archives:

1. record seven-day raw bytes/day and event counts by producer;
2. project 30- and 90-day index size with replica count one;
3. define disk high/critical watermarks and deletion behavior;
4. prove restore from backup;
5. enable archive indexing only if Wazuh dashboard search materially improves
   investigations over Loki and local archives.

### D6 — Detection before response automation

Wazuh creates alerts and notifications. It does not automatically block an IP,
disable an identity, mutate UniFi, isolate a host, or restart a workload in this
proposal.

### D7 — OpenBao audit evidence is file-first

OpenBao audit data is useful SIEM evidence, but a remote socket must not be its
only audit device. OpenBao can block requests when it cannot write audit
records, while UDP can lose records and TCP can fail during receiver outages.

- `homelab-iac` owns declarative audit-device intent, narrowly scoped policies,
  and safe drift-result metadata.
- The OpenBao runtime host owns a local file audit device, permissions, and
  rotation.
- A host Wazuh agent tails that file and sends authentication, authorization,
  policy, audit-device, and secret-access metadata to Wazuh.
- Loki retains ordinary OpenBao service journals.
- Request/response bodies, tokens, and secret values are excluded. Retain only
  identity/accessor, path, operation, result, source, and time needed for an
  investigation.

Implement this after the Discovery Wazuh agent exists. Until then, adding an
audit file would create sensitive evidence without a proven rotation and
transport path.

Live inventory on 2026-07-29 returned no enabled OpenBao audit devices. This is
a known evidence gap, not authorization to enable an unrotated local file or a
lossy remote-only device.

## Sister-repository evaluation

| Repository | Runtime/security surface | SIEM connection | Ownership decision |
|---|---|---|---|
| `desktop-nixos` | NixOS hosts, OpenSSH, auditd, systemd, firewall, k3s microVM substrate | Reusable Wazuh agent module for capable hosts; security-focused journal/audit/FIM collection; agent health metric | Owns agent package, enrollment projection, service hardening, host labels, and deployment |
| `homelab-iac` | UniFi, overlays, Cloudflare, GitHub and external control planes | Tailnet/LAN reachability and named source sets; document UniFi SIEM as UI-managed because the pinned provider exposes no SIEM resource | Owns ACL/firewall intent and external drift; no Wazuh workload |
| `servarr` | Compose workloads, Wazuh, Loki, Prometheus, Grafana, Discord routing | Wazuh runtime, decoder/rule files, archive policy, snapshots, dashboards, alert delivery, and container security-log selection | Primary SIEM runtime owner |
| `homelab-gitops` | Argo CD workloads, Kubernetes events, OTEL, in-cluster Alloy | Add one cluster security collection path for Kubernetes audit and selected workload events; no per-pod Wazuh agents | Owns Kubernetes objects and tests; substrate audit source remains `desktop-nixos` |
| `hermes-flake` | Hermes systemd/container/microVM packaging and service hardening | No repo-specific agent; deployed Hermes units are observed through the host agent. Alert on auth failures, denied operations, service identity/config changes, and sandbox-policy regressions | Module may expose structured safe metadata; host owns transport |
| `hermes-skills` | Read-only curated content and reviewed skill PRs | No runtime feed. Keep GitHub security/provenance checks; host FIM may watch the deployed read-only skill path without ingesting skill contents | Explicitly no agent or content ingestion |
| `home-assistant-config` | HAOS application config, auth events, Zigbee2MQTT/MQTT, Advanced SSH add-on | HAOS cannot consume the NixOS agent module. Evaluate a supported add-on/syslog export for authentication and add-on security logs; never ingest entity-state history by default | Repo owns safe logging config; HAOS appliance owns exporter/add-on lifecycle |
| `klipper-biqu` | Archinaut printer services, Moonraker, Klipper, SSH, config backup | Archinaut is resource-constrained and already uses Vector. Benchmark Wazuh agent before adoption; otherwise forward only SSH/auth and protected-config changes through the existing lightweight host path | `desktop-nixos` owns host transport; this repo identifies protected config paths |
| `kindle-dash` | Discovery container, LAN-only HTTP renderer, high-value OAuth/session credentials | No dedicated agent. Host/container events flow through Discovery. Alert on repeated HTTP failures, unexpected non-LAN clients, secret-file access/permission changes, and container control failure; do not ingest token values | `servarr` owns runtime logs; repo keeps logs redacted |
| `opencode-flake` | User CLI/profile and permission guardrails on workstations | No CLI session ingestion. Host agent covers login/audit and FIM for policy files; exclude prompts, sessions, tool arguments, and auth state | Package/profile repo stays telemetry-free |
| `codex-flake` | User CLI/profile; explicitly does not manage auth, logs, sessions, history, or state | Same host-only coverage as OpenCode; FIM profile policy, not user content | Package/profile repo stays telemetry-free |
| `ha-harness` | Private model serving, tool-call safety, shadow capture, sensitive audio/transcripts | Emit only authentication, authorization denial, unsafe-action decision, service health, and redacted policy metadata. Never send audio, transcripts, prompts, or entity-state payloads to Wazuh | App defines safe event schema; runtime host transports it |
| `cosmo-notes` | ESP32 firmware, Wi-Fi, Cloudflare Access, OTA, LiteLLM/Whisper transport | No device agent. Correlate UniFi client events, Cloudflare Access denials, gateway HTTP auth failures, DNS, and OTA integrity failures. Do not send note/audio content | Edge and gateway owners provide signals; firmware emits bounded status/error codes only |

## Target architecture

```text
NixOS audit/auth/FIM ── Wazuh agents over Tailscale ─┐
Kubernetes audit/security events ────────────────────┤
UniFi CEF + appliance syslog ── LAN UDP 5514 ───────┤
HAOS supported security-log export ──────────────────┤
Cloudflare/gateway security metadata ────────────────┤
                                                     ▼
                                       Wazuh manager on Kepler
                                         ├─ alerts → indexer/dashboard
                                         ├─ raw JSON archives
                                         └─ actionable alerts → #security

General journals/container logs ── Alloy/Vector → Loki
Health/dead-man metrics ─────────────────────────→ Prometheus/Grafana
Source/dependency findings ──────────────────────→ GitHub + #security
```

Kepler currently hosts Wazuh. Discovery is the 24/7 monitoring host, but moving
the stack there is not assumed. First measure Wazuh CPU, memory, disk, and
availability on Kepler. Propose migration only if Kepler's uptime or workload
contention violates the recorded SLO.

## Required improvements before fleet enrollment

### I1 — Strengthen the current Wazuh server

**Repository:** `servarr`

1. Split Wazuh API and indexer credentials; stop reusing one password.
2. Add explicit CPU/memory limits after measuring the live baseline.
3. Parse UniFi CEF extensions into structured fields, including device IP/MAC,
   source/destination IP, user, action, reason, and message.
4. Replace broad keyword-only warnings with event-signature rules after a
   seven-day UniFi sample; retain keyword fallback at lower severity.
5. Add alert rules for:
   - UniFi admin login/configuration changes;
   - IDS/IPS, honeypot, firewall deny, VPN, WAN failover, and device loss;
   - repeated events by source/device;
   - Wazuh manager/indexer/dashboard unhealthy;
   - receiver silence from expected appliances.
6. Add archive/indexer disk watermarks, retention metrics, and a restore-tested
   snapshot/backup path.
7. Add a redacted `#security` notification integration using the existing
   fleet contract; suppress duplicate Grafana/Wazuh notifications by assigning
   one owner per event class.

**Tests**

- Compose render test for TLS, secret separation, mounts, limits, and health.
- `wazuh-logtest` fixtures for the captured UniFi test event and one fixture
  per warning class.
- Malformed/escaped CEF fixtures must not crash decoding or mislabel severity.
- Synthetic UDP event reaches raw archive and expected alert index.
- Stop each Wazuh component and observe one control-health alert plus recovery.
- Fill a disposable index past the configured watermark and verify safe
  behavior.
- Restore configuration, certificates, rules, and an index snapshot into an
  isolated test stack.

**Revision gate**

- Review seven days of event volume and false positives.
- Reconcile UniFi's reported `192.168.50.57` management address with the network
  inventory before using it in an allowlist.
- Do not enable external notifications for a rule without a named operator
  action.

### I2 — Add the reusable NixOS agent module

**Repository:** `desktop-nixos`

Create one module, consumed by host roles rather than copied per host:

- pinned Wazuh agent package/version compatible with manager 4.14.6;
- manager address from fleet metadata;
- stable agent name equal to fleet hostname;
- enrollment credential projected from sops/Vault at runtime, never in the
  Nix store;
- TLS/server identity verification;
- least-privilege systemd hardening compatible with audit and FIM;
- security-focused inputs for sshd, sudo, auditd, fail2ban, firewall, Wazuh
  agent health, protected account files, and host-specific protected paths;
- no general application journal duplication.

Initial capable-host candidates:

`kepler`, `discovery`, `orion`, `endeavour`, `laptop`, and `pathfinder`.

Measure before adding:

`voyager`, `vanguard`, and `archinaut`.

K3s microVMs require a separate decision: either enroll each node for host
audit/FIM or collect the equivalent once from the substrate and Kubernetes
audit pipeline. Do not do both without a named detection gap.

**Tests**

- Nix evaluation proves the module renders only on selected hosts.
- Secret path appears in runtime unit configuration, never the store or world-
  readable output.
- Agent name and manager address match fleet metadata.
- Manager certificate failure prevents connection.
- Enrollment is idempotent and host redeploy preserves agent identity.
- Synthetic failed/successful SSH, sudo, protected-file mutation, audit loss,
  and fail2ban events produce the expected host-attributed rules.
- Agent stop triggers a control-health alert and recovery.
- Resource test records steady RSS, CPU, and events/minute on each host class.

**Revision gate**

- Enroll one canary workstation and one server first.
- Observe for seven days before expanding.
- Reject rollout on a host if steady agent memory exceeds 5% of RAM, sustained
  CPU exceeds 2%, or duplicate event volume has no detection value.

### I3 — Restrict network paths

**Repositories:** `homelab-iac`, then `desktop-nixos`

1. Add named SIEM server/agent source sets from fleet metadata.
2. Grant agents only Kepler `1514/tcp`; restrict `1515/tcp` to the enrollment
   window or selected unenrolled hosts.
3. Keep `5514/udp` LAN-only and `5601/tcp` LAN-bound.
4. Narrow the NixOS firewall from global port opens to the intended interfaces
   and source ranges where the firewall model permits it.
5. Record UniFi System Logging/SIEM as a UI-managed exception until the provider
   exposes a supported resource.
6. Add a drift checklist that verifies UniFi destination, port, CEF categories,
   and firewall-policy logging.

**Tests**

- Terraform/Terragrunt plan changes only intended ACL resources.
- Rendered Nix firewall accepts named agent/LAN sources and rejects an unrelated
  source.
- Tailnet agent can reach `1514`; cannot reach dashboard/indexer internals.
- LAN appliance can reach `5514`; WAN probe cannot.
- Enrollment port is closed after the enrollment batch.

**Revision gate**

- Capture before/after reachability from one allowed and one denied source.
- Re-plan after the next UniFi Network upgrade because the provider uses an
  internal API.

### I4 — Add Kubernetes security evidence once

**Repositories:** `desktop-nixos` (k3s audit source), then `homelab-gitops`
(collector/routing)

Start with Kubernetes API audit events and high-signal control-plane events:

- authentication/authorization failures;
- privileged pods, host namespaces, hostPath, and dangerous capabilities;
- Secret reads outside expected service accounts;
- RBAC, webhook, NetworkPolicy, and admission-policy changes;
- repeated pod exec/attach/port-forward;
- Argo drift or manual changes outside the GitOps identity.

Reuse an existing in-cluster collector only if it can forward the exact events
without a new privileged DaemonSet. Otherwise add one bounded collector, not an
agent per pod.

**Tests**

- Audit policy fixture includes the named event classes and excludes request/
  response bodies containing Secret data.
- Helm render plus kubeconform passes.
- A synthetic denied request and privileged-pod rejection reach Wazuh with
  cluster, namespace, workload, service account, verb, and result.
- Secret values and admission request bodies never appear.
- Collector loss alerts through the existing Prometheus/Grafana path.

**Revision gate**

- Measure audit volume for seven days.
- Tune policy stages/verbs before indexing.
- Keep operational pod logs in Loki.

### I5 — Cover appliances and constrained runtimes

**Repositories:** `home-assistant-config`, `klipper-biqu`, `cosmo-notes`,
`kindle-dash`, with transport owned by their runtime repository

Implement only supported, redacted events:

- HAOS: authentication failure/success, admin/config change, add-on start/stop,
  Zigbee2MQTT/MQTT authentication failures, and SSH add-on access.
- Archinaut: SSH/auth, sudo, backup failure, protected Klipper/Moonraker config
  changes, and security-control loss. Keep Vector if Wazuh agent cost is too
  high.
- Cosmo: UniFi connect/disconnect/anomaly, Cloudflare Access denial, gateway
  authentication failure, rate limiting, and OTA verification failure.
- Kindle renderer: unexpected source network, repeated HTTP failure, container
  failure, and protected credential-file permission/change events.

**Tests**

- Redaction fixtures contain no token, cookie, transcript, note, entity state,
  MQTT payload, or Wi-Fi secret.
- One synthetic event per producer reaches raw retention and its intended rule.
- Producer silence detection distinguishes an intentionally offline device from
  a failed control.
- CPU/memory/storage checks pass on HAOS and Archinaut before permanent rollout.

**Revision gate**

- No unsupported HAOS modification solely for Wazuh.
- No firmware telemetry service when edge/gateway logs already answer the
  question.
- No agent on Kindle, Cosmo, skills, or package repositories.

### I6 — Notify and operate

**Repositories:** `servarr` and `homelab`

Map Wazuh rules to the existing severity/response contract:

- level 3–5: retained/dashboard unless explicitly actionable;
- level 6–9: `#security`;
- level 10+: `#security`, plus `#incidents` only for confirmed access, live
  exposure, evidence loss, or control-plane compromise.

Messages contain rule, severity, host/device, redacted source, count, time, and
dashboard/runbook link. Disable mentions and never include raw event bodies.

**Tests**

- Force-fire one warning and one critical fixture.
- Observe exactly one firing and one resolution message.
- Repeated identical events respect the cooldown.
- Discord payload contains no raw log or secret-shaped field.
- Disable Wazuh manager and verify the independent external dead-man still
  reports the outage.

**Revision gate**

- Seven observe-only days per rule family.
- Remove or downgrade any alert with no operator action.
- Add central deduplication only after measured duplicate notifications.

## Rollout order

Land changes leaf-first:

1. `servarr`: harden server, structure UniFi fields, test backup/retention.
2. `homelab-iac`: narrow agent/SIEM network policy.
3. `desktop-nixos`: enroll Kepler and Endeavour canaries.
4. `desktop-nixos`: expand to capable NixOS servers/workstations.
5. `homelab-gitops`: Kubernetes audit/security pipeline.
6. Appliance/constrained-host slices only where retained evidence shows a gap.
7. `servarr`: enable notifications after observe-only gates.
8. `homelab`: record results, accepted exceptions, and final ownership.

Consumer changes pin the producer revision or artifact they depend on. No build
reads another working tree, and runtime Vault access remains the only live
cross-repository dependency.

## Fleet acceptance

The proposal is complete when:

- every active fleet host or appliance has an explicit SIEM connection or
  documented exclusion;
- Wazuh events carry stable host/device identity despite rootless forwarding;
- agent and appliance paths reject unauthorized sources;
- authentication, privilege, protected-file, network-security, and
  security-control-loss fixtures are detected;
- raw-event retention and alert-index retention fit measured disk budgets;
- index/config restore is proven;
- Wazuh loss is detected outside its own failure domain;
- notifications are redacted, deduplicated, actionable, and tested;
- Loki, Prometheus/Grafana, GitHub security, and Wazuh have non-overlapping
  authoritative responsibilities.

## Explicitly deferred

- Learned anomaly detection.
- Automatic blocking or host isolation.
- Suricata, Zeek, CrowdSec, or another event bus.
- Per-pod Wazuh agents.
- Full duplicate indexing of Loki journals.
- Wazuh agents on firmware, Kindle, skills, or packaging repositories.
- Moving Wazuh from Kepler before availability/resource evidence justifies it.
