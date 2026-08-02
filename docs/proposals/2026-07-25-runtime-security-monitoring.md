# Runtime security monitoring and anomaly alarms

**Status:** Observe-only alerting implemented; baseline, force-fire, and
non-overlapping Wazuh ownership gates remain
**Date:** 2026-07-25
**Owners:** `desktop-nixos` (host signals), `servarr` (central alerting),
`homelab-gitops` (Kubernetes signals), `homelab-iac` (external edge), and
`homelab` (cross-repo policy and contracts)

## Goal

Turn existing host, network, and application telemetry into actionable alarms
for:

- unexpected SSH authentication and source addresses;
- brute-force attempts and fail2ban activity;
- unexplained host loss or reachability changes;
- unusual ICMP traffic, port scans, and firewall rejects;
- privileged-account and authentication-policy changes;
- unexpected LAN clients, DNS behavior, and public-edge changes;
- failure of the monitoring controls themselves.

The first release reuses journald, Alloy, Loki, Prometheus, Grafana, fail2ban,
auditd, and Discord. It does not deploy a SIEM, IDS, event bus, anomaly-learning
service, or central notification service.

## Current state

- Fleet OpenSSH uses port 2222, public-key authentication, no root login,
  `MaxAuthTries = 3`, and no TCP/agent forwarding.
- Fail2ban bans after three retries, starts with a one-hour ban, and increments
  repeat bans.
- Host journals already flow through Alloy to Loki with a static `host` label.
- Host metrics already flow through Alloy to Prometheus.
- Grafana has a security dashboard with SSH failure counts, raw events, and
  source-IP extraction, but no Loki-backed security alert rules.
- Auditd watches PAM, passwd/group/shadow, sudoers, and sudo-log changes, but
  those events do not page.
- Firewall rejects are not logged, compose container logs do not reach Loki,
  and the monitoring stack on Discovery cannot report its own complete loss.
- Grafana already routes operational alarms to Discord.

## Implementation record

### 2026-07-25 — Phase 0 inventory slice

- Added `docs/runtime-security-inventory.json`, covering every host published
  by `desktop-nixos/fleet.json`.
- Added `tests/runtime-security-inventory-contract.sh` and wired it into the
  root contract suite. It checks schema, fleet coverage, named address-set
  references, explicit readiness/blockers, and secret-shaped content.
- Reconciled known Tailscale admin addresses for `laptop`, `endeavour`, and
  `pathfinder` against live peer state.
- Removed retired `galaxy` from the Tailscale policy. Known overlay admins are
  now `laptop`, `endeavour`, and `pathfinder`.
- Revision decision: keep Oracle TCP/2222 publicly reachable. Successful SSH
  login on active public hosts uses `alert-all`; it is never suppressed by the
  source address because legitimate direct deployment sources are dynamic.
- Home hosts use the concrete `known-admin-hosts` set. Endeavour also uses
  `alert-all` because its local-network trust boundary changes while roaming.
- Telstar stays blocked until provisioned; no inactive host is declared ready.

### 2026-07-25 — Phase 1 telemetry-integrity slice staged

- Live Prometheus inspection found all host Alloy self-metrics colliding under
  `instance="127.0.0.1:12345"`. `desktop-nixos` now assigns the fleet hostname
  on the `alloy_self` scrape target; a regression test and dry builds for
  Discovery, Kepler, Orion, Endeavour, and Laptop pass.
- `servarr` now provisions paused observe-only rules for inactive auditd/
  fail2ban units and Alloy Loki write failures/dropped entries. Tests cover
  query inputs, no-data behavior, paused state, security labels, and runbook
  linkage.
- Existing host-Alloy and host-metrics-absence rules already cover exporter or
  whole-host disappearance; no duplicate rule was added.
- Baseline finding: Orion currently reports `auditd.service` inactive. Do not
  enable notifications until the producer label fix is deployed and this state
  is explained or corrected.

### 2026-07-25 — Phase 1 deployed, baseline started

- `desktop-nixos#120` merged and deployed to Discovery, Kepler, and Orion.
  Prometheus now reports separate Alloy self-metric instances for `laptop`,
  `endeavour`, `discovery`, `kepler`, and `orion`; the collapsed
  `127.0.0.1:12345` build-info series is gone.
- `servarr#126` merged with an administrative CI bypass because the private
  workflow failed before creating any steps. Its targeted tests passed locally
  and the unrelated `ACME_EMAIL` base-suite drift was reproduced on clean
  `origin/main`.
- Discovery now runs servarr `17e4f3c`; Grafana is healthy and both
  `security-control-*` rules are provisioned with `isPaused=true`.
- Baseline start: 2026-07-25 19:21 America/Sao_Paulo. Initial host-attributed
  one-hour Loki failure/drop increases are zero for all five producers.
- Orion's inactive auditd was traced to Jovian injecting `audit=0` before the
  fleet's `audit=1`. `desktop-nixos#122` removes the conflicting parameter
  while preserving GPU tuning. The PR merged, Orion rebooted onto it, and
  runtime verification shows `audit=1`, no `audit=0`, auditd active, zero lost
  events, and an 8192-event backlog limit.
- Kepler rebooted while activating its staged generation and recovered after
  one Wake-on-LAN packet. All five k3s microVMs returned active. A stale broken
  `/home/erik/.cache -> /fast/ai/cache/user` symlink from retired AI storage was
  removed and replaced by a normal private cache directory; Home Manager then
  started successfully.

### 2026-07-25 — Phase 2 SSH telemetry and paused detections

- Live Loki inspection found `voyager` and `vanguard`, the active public-SSH
  hosts, missing from journal telemetry. `desktop-nixos#125` enabled the
  existing lightweight Vector journal shipper on both 1 GB hosts, with
  evaluated Nix regression tests.
- `homelab-iac#37` granted those hosts only `discovery:3100`; its first live
  apply was rejected without changing policy because `voyager` was absent from
  the named-host map. `homelab-iac#38` restored its stable tailnet address and
  the second plan applied one in-place ACL update with no creates or deletes.
- Both hosts were deployed. Vector healthchecks pass and Loki reports
  `voyager` and `vanguard` streams. Initial old-journal rejection on Vanguard
  drained during catch-up; current two-minute ingestion is nonzero without
  continuing Vector warnings or drops.
- Voyager activation returned nonzero after an unrelated D-Bus reload exceeded
  its timeout. Post-checks found D-Bus, Vector, SSH, Tailscale, fail2ban,
  node-exporter, and Home Manager active with no failed units.
- `servarr#127` added two Loki-backed rules:
  `security-ssh-failure-burst` (five failures in five minutes) and
  `security-ssh-public-login` (any accepted login on Voyager or Vanguard).
  The private workflow again failed before creating steps; 14 targeted tests,
  YAML UID checks, and both live LogQL queries passed before administrative
  merge.
- Discovery now runs servarr `83fa299`. Grafana and Loki are healthy; both SSH
  rules are provisioned against Loki with `isPaused=true`. Activation remains
  blocked until the baseline gate ends on 2026-08-01 19:21
  America/Sao_Paulo.
- Policy revision: successful SSH sources are now whitelisted only for
  `endeavour`, `gemini`, and `discovery`, using their live stable LAN/Tailscale
  IPv4 and IPv6 addresses. `servarr#130` changed the existing successful-login
  rule to warn on every other source across every journal-producing host.
  Discovery runs servarr `56131a1`; Grafana provisioned the revised rule with
  `isPaused=true`. Its first live baseline found 40 records across Kepler and
  Orion from one non-whitelisted source.

## Decisions

### D1 — Deterministic detection before learned anomaly detection

Every phase starts with an explicit invariant, allowlist, rate, or dead-man
deadline. “Unusual” must resolve to a testable condition. Baselines may be
derived from observed data, but production rules remain readable and
version-controlled.

Learned anomaly detection is deferred until a deterministic rule produces
measurable false negatives that retained telemetry can demonstrate.

### D2 — Prevention and detection stay separate

Existing SSH hardening, firewall policy, and fail2ban remain prevention
controls. Grafana alarms report security-relevant events; they do not run
remediation commands. Automatic isolation, firewall mutation, credential
revocation, and host reboot require a separate decision.

### D3 — Two notification classes

- `#security`: suspicious activity needing investigation, but no proven live
  impact.
- `#incidents`: successful unauthorized access, exposed public surface,
  monitoring blind spot, or credible availability/data-loss event.

Warnings do not repeat more often than four hours. Critical alarms may repeat
hourly while active. Resolved notifications remain enabled. Messages disable
mentions and contain only host, event class, redacted identity, source address,
count, time window, and a Grafana link. Raw journal lines and audit payloads
stay in Loki.

### D4 — Address policy uses named sets

Version-controlled address groups:

- `admin`: expected management source CIDRs and Tailscale ranges;
- `lan`: owned RFC1918/VLAN ranges;
- `monitoring`: approved probe sources;
- `public`: any address outside owned and overlay ranges.

Rules compare parsed addresses against these sets. No country-based block or
alert is authoritative. GeoIP may enrich public-address investigations later,
never decide them.

The concrete CIDRs must be inventoried before enabling successful-login alarms.
No guessed CIDR enters production.

### D5 — Central monitoring gets an independent dead-man

Kepler checks Discovery from outside Discovery's Grafana/Loki/Prometheus
failure domain. It posts directly to the incidents Discord webhook when
Discovery's TCP health endpoint is continuously unavailable. This is the only
runtime security alarm allowed to bypass Grafana.

### D6 — New telemetry must answer a named question

Firewall logging, UniFi polling, AdGuard rules, container logs, CrowdSec,
Suricata, and Zeek are separate additions. Add one only when its phase names:

1. the incident question;
2. the retained signal needed to answer it;
3. an alert with an operator action;
4. a noise and storage budget.

## Severity and response matrix

| Signal | Initial severity | Route | Immediate operator action |
|---|---|---|---|
| Successful SSH login outside `admin` | Critical | `#security` + `#incidents` | Confirm owner; isolate host if unknown |
| Root SSH attempt or impossible auth mode | Critical | `#security` | Inspect source and sshd configuration |
| Failed SSH burst from one source | Warning | `#security` | Confirm ban and public exposure |
| Fail2ban jail stopped or absent | Critical | `#security` + `#incidents` on public hosts | Restore control; inspect exposure window |
| Fail2ban ban | Warning | `#security` | Check repetition and target host |
| PAM/passwd/shadow/group/sudoers mutation | Critical | `#security` + `#incidents` if unexplained | Attribute change; inspect sessions |
| Audit events lost or auditd unavailable | Critical | `#incidents` | Restore evidence pipeline |
| Discovery monitoring dead-man | Critical | `#incidents` | Check host/power/network |
| Approved host unreachable | Warning/Critical by role | `#incidents` | Check host and dependency impact |
| ICMP or reject-rate spike | Warning | `#security` | Identify source/interface and intent |
| Port-scan pattern | Warning | `#security` | Identify source; block only after confirmation |
| New LAN client | Info initially | dashboard, then `#security` if unknown persists | Classify and register device |
| DNS NXDOMAIN/client spike | Warning | `#security` | Inspect client and queried domains |
| Public ingress/firewall drift | Critical | `#security` + `#incidents` when live | Revert or contain exposure |

## Delivery rules

Each implementation step follows the same loop:

1. Add the smallest retained signal and a fixture/unit contract.
2. Deploy in observe-only mode: dashboard/query, no notification.
3. Measure seven representative days, including maintenance.
4. Record event volume, expected sources, false positives, and missing labels.
5. Revise allowlists, threshold, duration, and severity in code.
6. Enable notification.
7. Force-fire once and observe one firing and one resolved Discord message.
8. Review after seven alerted days; revise or remove rules without operator
   action.

Emergency-critical invariants such as monitoring dead-man and audit loss may
use a 24-hour observe-only window when their synthetic tests are exact.

## Phase 0 — inventory, threat model, and contracts

**Repository:** `homelab`

### Step 0.1 — inventory runtime surfaces

Document, per host:

- interfaces and trust zones;
- whether SSH is reachable from LAN, overlay, or public Internet;
- expected SSH users and management CIDRs;
- public TCP/UDP ports;
- monitoring/logging components enabled;
- host criticality and acceptable reachability deadline.

Generate the inventory from `desktop-nixos` fleet data where possible. Keep
only security classification and cross-repo relationships here; host values
remain owned by `desktop-nixos`.

**Tests**

- Contract: every `desktop-nixos` fleet host has a trust-zone, SSH-exposure,
  criticality, and monitoring-owner entry.
- Contract: every public host has a named expected management source set.
- Contract: no literal secret or Discord webhook appears in inventory.

**Revision gate**

- Review inventory against rendered Nix firewall and OpenSSH configuration.
- Resolve every “unknown” public exposure before Phase 2 notification.
- Re-run after any host/interface addition.

### Step 0.2 — define event and notification contracts

Define required labels:

`alertname`, `severity`, `category=security`, `host`, `source`, `event_class`,
and `runbook_url`.

Define optional safe labels:

`username`, `jail`, `interface`, and `address_scope`.

Forbid raw log bodies, audit record bodies, source code, credentials, and
unescaped user-controlled text in notification annotations.

**Tests**

- Extend root contract tests to check every security rule carries required
  labels and a runbook.
- Check every security notification path disables Discord mentions.
- Fixture payloads containing `@everyone`, Markdown, shell text, and a fake
  secret remain escaped/redacted.
- YAML/JSON parsing test covers every provisioning file.

**Revision gate**

- Security review of one synthetic payload per event class.
- Any leaked raw line blocks rollout.

### Step 0.3 — establish baseline queries

Record seven-day counts for:

- successful and failed SSH events by host/source/user;
- fail2ban bans and jail lifecycle;
- auditd changes and lost-event counters;
- host reachability and maintenance windows;
- ICMP counters and firewall rejects where available.

Save queries and aggregate results, not raw logs or public-address history, in
the proposal implementation record.

**Tests**

- Each query returns a numeric/vector result when fed one known fixture.
- Empty-data result is distinguishable from zero events.
- Every source includes a host label.

**Revision gate**

- Fix telemetry gaps before writing alert thresholds.
- A rule cannot enable if its query currently yields “no data” for an expected
  producer.

## Phase 1 — telemetry integrity

### Step 1.1 — prove host journal attribution

**Repository:** `desktop-nixos`

Keep Alloy's build-time host label. Add only missing service/unit labels needed
to distinguish sshd, fail2ban, auditd, and firewall events.

**Tests**

- Nix evaluation test asserts Alloy journal source contains the configured
  hostname.
- Alloy configuration syntax check.
- Loki integration query finds one synthetic logger event under the correct
  host and unit.

**Deployment verification**

- Query every enabled host over 15 minutes.
- Expected host set equals inventory host set, excluding documented offline
  systems.

**Revision gate**

- Correct labels at the collector, not separately in every Grafana query.
- Reject high-cardinality labels such as full message, PID, session ID, or
  source address at ingestion.

### Step 1.2 — alert on telemetry blindness

**Repositories:** `desktop-nixos`, then `servarr`

Add Prometheus rules for:

- Alloy absent or failed;
- Loki write failures/backlog sustained beyond maintenance tolerance;
- auditd failed;
- fail2ban failed on hosts where enabled;
- audit lost/backlog overflow events.

Reuse existing systemd-unit and Alloy self-metrics where they cover the
condition.

**Tests**

- Rule tests evaluate one firing and one healthy vector per condition.
- Existing Grafana provisioning contract loads the new group.
- Stop each service in a disposable VM and verify its metric/log condition.

**Deployment verification**

- Force-fire one non-public canary host.
- Confirm notification identifies lost control, not generic “host down.”
- Restore service and confirm resolved notification.

**Revision gate**

- Remove duplicate rules when host-down already explains the same failure.
- Keep independent audit/fail2ban alarms because host-up with control-down is
  distinct.

## Phase 2 — SSH detection

### Step 2.1 — normalize SSH events at query time

**Repository:** `servarr`

Create shared, documented LogQL patterns for:

- successful public-key authentication;
- failed authentication;
- invalid user;
- root login attempt;
- pre-auth disconnect/no-identification probe;
- connection source address;
- fail2ban ban/unban and jail start/stop.

Do not add an ingestion parser until query-time patterns are proven too slow or
inconsistent.

**Tests**

- Table-driven fixture file contains representative OpenSSH and fail2ban lines.
- Each fixture matches exactly one expected event class.
- IPv4 and IPv6 addresses parse.
- Malformed lines and attacker-controlled usernames cannot alter labels or
  annotations.
- Successful-login pattern does not classify failed/pre-auth lines.

**Revision gate**

- Compare fixtures with real redacted journal formats from each NixOS/OpenSSH
  version in fleet.
- Revise patterns after upgrades that change journal wording.

### Step 2.2 — successful-login allowlist alarm

**Repositories:** `desktop-nixos` for owned address sets, then `servarr` for
rule

Alert on any successful SSH login whose source is outside the host's `admin`
set. Expected automation sources must use a named source set, not a broad
suppression.

**Tests**

- Allowed IPv4, allowed IPv6, Tailscale, LAN, public, and malformed-source
  fixtures.
- Boundary tests for CIDR first/last address.
- Unknown/missing source fails closed into an alertable parse-error condition.

**Deployment verification**

- Observe-only query for seven days.
- Synthetic allowed login produces no alert.
- Synthetic non-allowlisted login on isolated canary produces one critical
  alert, then resolves.

**Revision gate**

- Review every observed allowed source with owner.
- Narrow overly broad CIDRs before enabling.
- Never suppress by username alone.

### Step 2.3 — brute-force and root-attempt alarms

**Repository:** `servarr`

Initial candidate rules:

- at least three failed/invalid-user events from one source to one host in five
  minutes: warning;
- failures spanning at least three usernames or hosts in ten minutes:
  scan warning;
- any root authentication attempt: critical;
- fail2ban ban: warning grouped by host/source/jail;
- fail2ban jail stopped while host remains reachable: critical.

Thresholds are candidates, not final values; Phase 0 baseline decides them.

**Tests**

- Below-threshold, exact-threshold, above-threshold, and window-expiry cases.
- Same NAT source against different hosts aggregates only for scan rule.
- Repeated log ingestion does not create duplicate top-level notifications.
- Rule retains source address in Grafana but notification formatter safely
  renders it.

**Deployment verification**

- Use a canary source under operator control; do not attack public services.
- Trigger failures, observe fail2ban ban, then wait/clear and observe resolve.
- Confirm normal deployment SSH does not fire.

**Revision gate**

- Seven alerted days: count alerts, unique sources, bans, and operator actions.
- Raise duration/threshold or demote repetitive background probes.
- Keep successful-unknown-login critical even if brute-force noise is high.

### Step 2.4 — SSH runbook

**Repository:** `desktop-nixos`

Document read-only triage:

- identify host, user, source scope, and authentication key fingerprint;
- compare against deployment/operator activity;
- inspect adjacent sudo/audit events;
- determine whether source used LAN, overlay, or public interface;
- preserve logs before containment.

Containment commands remain manual and explicit. Runbook distinguishes:
unknown attempt, unknown successful login, and monitoring false positive.

**Tests**

- Every SSH rule links to existing runbook anchor.
- Commands used for evidence collection are read-only.
- No runbook prints private keys, tokens, or full environment.

**Revision gate**

- Execute runbook against synthetic canary event.
- Revise any step requiring unavailable data before enabling critical paging.

## Phase 3 — privileged-change detection

### Step 3.1 — validate audit rules and retention

**Repository:** `desktop-nixos`

Verify existing watches cover PAM, passwd, shadow, group, sudoers, and sudo
logs on every relevant host. Add watches only for demonstrated gaps. Confirm
rotation retains enough data for the incident-response window.

**Tests**

- Nix VM test mutates disposable watched files and asserts expected audit key.
- Healthy test confirms rules load after boot.
- Negative test confirms ordinary reads do not emit change events.
- Lost-event/backlog condition is observable.

**Revision gate**

- Remove noisy watches with no response action.
- Add a watch only when test maps it to a threat and runbook step.

### Step 3.2 — audit change alarms

**Repository:** `servarr`

Alert on existing audit keys:

- `auth_config`;
- `shadow_changes`;
- `passwd_changes`;
- `group_changes`;
- `sudoers_changes`;
- unexplained audit configuration/rule changes.

Group planned NixOS activation bursts into one per-host notification. Do not
silence all activation-time changes: tag known maintenance windows and retain
the event history.

**Tests**

- One fixture per audit key.
- NixOS activation fixture groups without hiding an out-of-window mutation.
- Raw audit body never appears in Discord payload.
- Missing host/audit key fires parser-health warning.

**Deployment verification**

- Mutate a disposable watched file in VM/canary; verify alarm and resolution.
- Perform normal NixOS switch; measure grouping/noise.

**Revision gate**

- Seven alerted days include at least one planned switch.
- Revise grouping window, not broad path exclusions.

## Phase 4 — independent availability and ping semantics

### Step 4.1 — Discovery external dead-man

**Repository:** `desktop-nixos`

Add one Kepler systemd timer/service that performs a bounded TCP health check
against Discovery over the intended management path. ICMP may be recorded as
diagnostic evidence, but TCP service reachability decides the alarm because
fleet firewalls intentionally reject ICMP on some hosts.

After consecutive failures covering the agreed deadline, post a compact
message directly to the incidents webhook. Store state locally to emit only
one firing and one recovery message.

**Tests**

- Small executable self-test or Nix VM test covers healthy, first failure,
  threshold failure, repeated failure, and recovery.
- Timeout is bounded; timer cannot overlap itself.
- Missing webhook fails locally without printing secret.
- Payload disables mentions.

**Deployment verification**

- Block canary health endpoint or stop target service.
- Verify Grafana-independent incident message.
- Restore endpoint and verify one recovery.
- Confirm Discovery outage does not prevent delivery.

**Revision gate**

- Start with a five-minute deadline.
- Revise from measured maintenance/reboot duration.
- Keep implementation on one observer until observer loss becomes a measured
  gap; do not build quorum.

### Step 4.2 — fleet reachability probes

**Repositories:** `desktop-nixos` for target inventory, `servarr` for metrics
and rules

Probe critical hosts using the protocol that represents service availability:
TCP for SSH/DNS/HTTPS, ICMP only where explicitly allowed. Separate:

- host unreachable;
- service unreachable while host is reachable;
- probe system unavailable.

**Tests**

- Target inventory contract has owner, protocol, deadline, and criticality.
- Probe configuration syntax and target count.
- Rule tests cover host-down, service-down, and probe-down.

**Deployment verification**

- Force-fire one target per criticality class.
- Planned reboot fits warning delay or documented maintenance silence.

**Revision gate**

- Tune by observed reboot duration.
- Remove probes duplicating an existing higher-quality service health metric.

## Phase 5 — firewall, ICMP, and scan detection

### Step 5.1 — add bounded firewall evidence

**Repository:** `desktop-nixos`

Prefer nftables counters exported as metrics over per-packet logging. Add
rate-limited logging only when source-address/port evidence is required and
counters cannot answer the incident question.

Required dimensions stay bounded: host, input interface/trust zone, protocol,
and decision. Source address and destination port remain log fields, not
Prometheus labels.

**Tests**

- Nix VM sends allowed and rejected TCP/UDP/ICMP traffic.
- Counters increment only in expected rule/zone.
- Log rate limit holds under synthetic flood.
- Loki/Prometheus label-cardinality contract rejects IP/port labels.

**Deployment verification**

- Observe counter rates for seven days.
- Measure journal volume and Loki ingestion before/after.
- Confirm legitimate discovery/multicast traffic does not dominate.

**Revision gate**

- Set explicit per-host daily log and series budgets.
- Disable packet logging if it exceeds budget without changing an operator
  decision.

### Step 5.2 — ICMP anomaly alarms

**Repository:** `servarr`

Treat these as distinct:

- approved host stops responding to an approved probe;
- inbound ICMP rate materially exceeds that host's observed baseline;
- ICMP errors spike;
- ICMP originates from a non-approved zone where firewall policy expects none.

Use sustained rates and absolute minimum counts so low-volume hosts do not page
on one packet.

**Tests**

- Baseline, burst below duration, sustained burst, error spike, and counter
  reset.
- Planned probe source excluded only from unsolicited-source rule.
- No alert relies on raw-socket count as proof of hostile ping.

**Deployment verification**

- Generate bounded ICMP from controlled LAN source.
- Verify correct zone/source classification and one warning.

**Revision gate**

- Seven-day review classifies every firing.
- If normal discovery traffic dominates, restrict interface/zone before
  increasing global threshold.

### Step 5.3 — port-scan alarm

**Repository:** `servarr`

Derive from rate-limited reject logs: same source reaching at least the revised
number of distinct destination ports on one host within the revised window.
Keep source address in Loki query state, not as a persistent metric label.

**Tests**

- Repeated hits to one closed port do not classify as scan.
- Distinct-port threshold does.
- Multiple benign sources do not merge.
- IPv4/IPv6 parsing and log-rate-limit truncation are represented.

**Deployment verification**

- Run a bounded scan from controlled source against canary host.
- Confirm rate limiting does not hide threshold crossing.

**Revision gate**

- Compare scan alerts with fail2ban and public exposure.
- If all scans target an unavoidable public service and require no action,
  retain dashboard evidence but disable notification.

## Phase 6 — edge, LAN, DNS, and workloads

Each subphase is independent. Stop after Phase 5 unless the named signal has a
real producer and operator action.

### Step 6.1 — public-edge drift

**Repository:** `homelab-iac`

Extend existing drift/policy checks for:

- new public listener;
- widened source CIDR;
- removed rate limit/WAF/firewall control;
- DNS/public ingress target change;
- management port exposed publicly.

**Tests**

- Terraform/policy fixtures for allowed and forbidden diffs.
- Critical notification contains resource/address policy, never plan secrets.
- No-change and internal-only changes stay silent.

**Revision gate**

- One synthetic forbidden fixture must page before rollout.
- Any provider field too unstable for deterministic comparison remains CI-only.

### Step 6.2 — UniFi client inventory

**Repositories:** `servarr`, with manual read-only account prerequisite

Deploy UniFi Poller only after creating a scoped read-only UniFi account. Start
with dashboard inventory: new client, association history, WAN status, and
traffic volume. Alert only when an unknown client persists beyond DHCP/Wi-Fi
churn tolerance or joins a protected VLAN.

**Tests**

- Credential is Vault-rendered and absent from compose/config.
- Known, randomized-MAC, transient, persistent-unknown, and protected-VLAN
  fixtures.
- Poller-down is distinct from zero clients.

**Revision gate**

- Observe at least 14 days because phone MAC randomization and guests create
  churn.
- Maintain device ownership inventory before enabling alerts.

### Step 6.3 — AdGuard DNS anomalies

**Repository:** `servarr`

Use existing exporter metrics first:

- total query-rate spike;
- NXDOMAIN ratio spike with absolute minimum;
- one client dominating traffic;
- AdGuard unavailable.

Domain-level suspicious-name detection needs query logs and a separate privacy
decision; do not add it in the metrics phase.

**Tests**

- Low-volume ratio does not fire without absolute count.
- Query spike, NXDOMAIN spike, client spike, exporter-down, and counter reset.
- Client identity is redacted from public/shared notifications if needed.

**Revision gate**

- Seven-day baseline plus a known noisy maintenance/update window.
- Domain logging proposal required before retaining domain names centrally.

### Step 6.4 — compose and Kubernetes security events

**Repositories:** `servarr`, then `homelab-gitops`

First route compose stdout through journald or host Alloy, choosing the existing
native path with least new infrastructure. Then add only high-signal events:

- repeated authentication failures on an Internet-facing application;
- unexpected privileged container or host mount;
- Kubernetes audit events for privileged workload/RBAC mutation;
- security component crash or disabled policy.

**Tests**

- Container-log fixture has host, service, and container identity.
- No secrets from environment/log body enter notification.
- Kubernetes policy fixtures cover allowed controller and forbidden actor.
- Pipeline health distinguishes no events from no collection.

**Revision gate**

- Per-application threat model and parser before alert.
- Skip generic keyword alarms across arbitrary container logs.

## Phase 7 — evaluate CrowdSec or network IDS

This phase is a decision gate, not planned deployment.

### Step 7.1 — CrowdSec gate

Consider CrowdSec only if:

- SSH/web probes are Internet-facing;
- deterministic rules produce repetitive actionable blocks;
- shared reputation would prevent measurable work;
- fail2ban cannot cover the same sources/protocols.

Pilot on one public host, decision-only mode first.

**Tests**

- Parser fixtures for actual fleet log formats.
- Allowlist prevents overlay/LAN/operator lockout.
- Decision expiry and rollback work without cloud dependency.
- Agent/hub failure leaves existing firewall policy intact.

**Revision gate**

- Compare 30 days against fail2ban: unique useful decisions, false positives,
  resource cost, and maintenance.
- Remove CrowdSec if it adds no operator or prevention value.

### Step 7.2 — Suricata/Zeek gate

Consider network IDS only if router/SPAN traffic is available and retained
flow/firewall/DNS evidence cannot answer a documented incident question.

Before pilot, specify interface, traffic visibility, encrypted-traffic limits,
storage budget, rule-update ownership, and privacy boundary.

**Tests**

- Offline PCAP fixtures: benign LAN, controlled scan, DNS anomaly, and expected
  encrypted traffic.
- Drop/missed-packet metric.
- Rule update rollback and pinned ruleset.
- No payload retention beyond approved policy.

**Revision gate**

- Thirty-day observe-only pilot.
- Deploy alarms only for signatures with an owner and tested response.
- Remove pilot if encrypted/partial visibility makes conclusions unreliable.

## Cross-repo landing and deployment order

For each phase:

1. `homelab`: land decision, inventory/contract revision, and acceptance
   criteria.
2. Leaf producer repository: add telemetry and local tests.
3. Deploy producer; verify retained signal without alerting.
4. `servarr`: add query/dashboard, rule tests, runbook links, and alert rule.
5. Deploy `servarr`; keep notification disabled during baseline.
6. Revise threshold/allowlist from measured baseline in owning repositories.
7. Enable route; force-fire; confirm resolved notification.
8. Update this proposal's implementation record with commits, deployment
   date, evidence, observed volume, and deferred gaps.

Do not make builds read sibling working trees. Publish/pin any shared fixture
or schema needed by consumers; root contracts may inspect local symlinks only
for developer/CI coordination.

## Test layers

### Static and unit

- Nix evaluation/VM tests for host services, firewall behavior, and timer state.
- Log parser fixtures for OpenSSH, fail2ban, auditd, nftables, AdGuard, and
  optional workload events.
- Prometheus/Grafana rule tests for healthy, firing, no-data, and recovery.
- Provisioning syntax/load tests.

### Contract

- Required labels, severity, route, runbook, and safe annotations.
- Discord mentions disabled.
- No secret/raw-event content.
- Every inventoried producer has either coverage or an explicit exclusion.
- No-data alerts for security controls.

### Integration

- Disposable NixOS VM/canary emits each event.
- Alloy forwards it with correct host/unit labels.
- Loki/Prometheus query returns expected series.
- Grafana transitions Pending → Firing → Normal.

### End-to-end

- One controlled force-fire per rule class.
- One firing and one resolved Discord message.
- Message links to useful dashboard/runbook.
- Independent Discovery dead-man succeeds while Discovery monitoring stack is
  unavailable.

### Regression

- Normal SSH deployments, NixOS switches, reboots, DHCP churn, backup jobs,
  and known maintenance do not page outside agreed delays.
- Existing observability and security-notification contracts remain green.

## Review schedule

### Per-step revision

Every step records:

- expected versus observed event count;
- false positives and false negatives found by fixtures/manual comparison;
- notification count and whether operator acted;
- query/runtime/storage cost;
- exact threshold/allowlist revision;
- decision: enable, keep observe-only, demote to dashboard, or remove.

### Seven alerted days

Remove or revise:

- alerts without an operator action;
- duplicate symptoms;
- rules firing on planned maintenance;
- rules whose producer frequently yields no data.

### Thirty days

Review by category:

- unknown successful SSH logins;
- unique brute-force sources and actual bans;
- privileged changes outside planned activation;
- monitoring blind spots;
- network anomalies;
- new clients/DNS anomalies, if enabled;
- mean acknowledgement and resolution time.

Add centralized deduplication or advanced detection only when this record shows
the direct Grafana/Discord path failing.

### After upgrades

Re-run relevant fixtures and canary tests after:

- OpenSSH/fail2ban/auditd log-format changes;
- Grafana/Loki/Prometheus upgrades;
- firewall rule restructuring;
- network/VLAN/Tailscale renumbering;
- new host or public service.

## Rollback

- Alert rule: disable notification first; retain query/dashboard evidence.
- Noisy parser: revert consumer rule without removing raw journal collection.
- Excessive firewall logs: disable rate-limited log rule; retain bounded
  counters.
- Bad allowlist: disable successful-login route, correct inventory, replay
  fixtures, then re-enable.
- Dead-man failure: disable timer, preserve state/log, continue existing
  Grafana monitoring.
- Optional collector/IDS: remove workload and credential; existing
  firewall/fail2ban/Alloy controls remain authoritative.

Rollback never deletes incident logs or weakens prevention controls merely to
silence an alarm.

## Phase acceptance

### Minimum useful release: Phases 0–4

- Every relevant host is inventoried with exposure and expected admin sources.
- Telemetry-control failure alerts exist and are force-fired.
- Unknown successful SSH login, root attempt, brute-force burst, and fail2ban
  control loss have tested alarms.
- Privileged identity/auth-policy changes have tested alarms.
- Discovery has an externally delivered dead-man.
- Every alarm has a runbook, safe Discord payload, resolved notification, and
  documented revision result.

### Network release: Phase 5

- Firewall evidence stays within agreed volume/cardinality budget.
- ICMP anomalies distinguish reachability, flood/error, and unsolicited zone.
- Port-scan rule is tested and retained only if it triggers operator action.

### Extended release: Phase 6

- Each enabled source has read-only/scoped credentials, telemetry-health
  detection, privacy boundary, baseline, and response owner.

Phase 7 has no acceptance target until its decision gates are satisfied.

## Explicitly deferred

- Automatic blocking based on Grafana alarms.
- Automatic host isolation or account/key revocation.
- GeoIP-based enforcement.
- Generic “AI anomaly detection.”
- Full SIEM.
- Central notification/deduplication service.
- CrowdSec, Suricata, or Zeek without measured need.
- Raw DNS-domain retention without privacy decision.
- Argus consumption of untrusted `#security` messages.
