# Stack-wise security, monitoring, and resilience hardening

**Status:** Proposed after cross-repository source audit; P0 containment not started
**Date:** 2026-08-16
**Last reviewed:** 2026-08-16
**Owners:** `homelab` (gates and evidence), `homelab-iac` (edge/network and
GitHub control plane), `desktop-nixos` (hosts and cluster substrate), `servarr`
(Compose, monitoring, and Wazuh), `homelab-gitops` (lab Kubernetes), and each
leaf repository for its application or device contract

## Goal

Reduce the fleet's useful attack surface, make hostile or authorized-pentest
activity visible, and improve recovery without installing a second security,
monitoring, ingress, or orchestration stack.

This is an execution map over existing records, not a replacement for them:

- [fleet alerting reliability and response](2026-08-28-fleet-alerting-reliability-and-response.md)
  owns deterministic runtime detections, delivery, response, and external
  dead-man behavior;
- [fleet Wazuh integration](2026-07-26-fleet-wazuh-siem-integration.md) owns
  security events, agent rollout, retention, and SIEM restore;
- [network segmentation](2026-08-01-network-router-security-segmentation.md)
  owns VLANs, IDS/IPS, honeypot, listener drift, and lateral-scan policy;
- [stateful release hardening](2026-07-13-stateful-stack-release-hardening.md)
  owns workload backup, restore, migration, and rollback gates, including the
  secondary fleet DNS gate (its P3);

## Audit scope and limits

The audit inspected every repository in `repos.json`, current workflow triggers,
host/network policy, Compose publications, Kubernetes manifests, application
trust boundaries, and the proposal portfolio. It was source-only: no live
scanner, provider apply, secret read, or remote mutation was performed.

Dirty work already exists in `desktop-nixos`, `homelab-iac`, `servarr`, and
`homelab-gitops`. Every implementation slice must start from an isolated clean
branch and must not absorb those unrelated changes.

Source evidence can lag runtime state. Each gate therefore requires both a
source test and a bounded live proof from one allowed and one denied path.

## Existing controls to keep

- Fleet SSH is key-only on TCP/2222 with root login and forwarding disabled;
  host firewalls and fail2ban are enabled.
- Tailscale policy has explicit positive and negative tests. Public HA and
  Whisper use outbound Cloudflare Tunnel paths and Cloudflare Access; Whisper
  also has an IaC-managed rate limit.
- Host and container logs use Alloy/Vector and Loki. Metrics use
  Prometheus/Grafana. The Discovery dead-man is declared independently on
  Kepler and Vanguard.
- Wazuh on Kepler receives UniFi CEF, has disk watermarks, encrypted snapshots,
  and proven isolated local/offsite restores.
- OpenBao and OpenTofu state have local, off-host, and provider-diverse backup
  paths plus restore drills.
- Kubernetes has three embedded-etcd control-plane VMs, host-backed snapshots,
  Pod Security Admission at `baseline`, and a restricted/default-deny demo
  namespace.
- Renovate pins digests and GitHub Actions. Kindle releases additionally use
  Trivy, SBOM/provenance, Cosign, immutable digests, and consumer verification.
- The HA harness requires a bearer token and has adversarial, confirmation,
  shadow, and authoritative-executor tests.

Do not replace these with CrowdSec, another SIEM, another metrics stack, a
service mesh, or a second ingress controller without a measured gap.

## Verified priority findings

| Priority | Finding | Evidence | Required result |
|---|---|---|---|
| P0 | Private-repository secret scans are manual-only, while primary validation workflows are PR-only and private `main` branches are unprotected. `homelab-iac` runs Trivy but no repository secret scan. | Private `.github/workflows/security.yml` files declare only `workflow_dispatch`; `github/repos/terragrunt.hcl` sets `protect_main = false` for private repos. | Run secret and validation checks on every PR and push to `main`; add Gitleaks to IaC. Decide separately whether to buy the GitHub entitlement required for enforceable private rulesets. |
| P0 | Home Assistant accepts forwarded identity from `172.0.0.0/8`, plus gateway and Tailscale `trusted_proxies` entries, with `use_x_forwarded_for` enabled. | `home-assistant-config/configuration.yaml` `http.trusted_proxies`. | Re-derive the entire `trusted_proxies` list to the exact proxy/container addresses; prove direct clients cannot spoof `X-Forwarded-For`. |
| P0 | Moonraker trusts all of `10/8`, `172.16/12`, and `192.168/16` for a physical-control API. | `klipper-biqu/printer_data/config/moonraker.conf`. | Restrict to named HA/admin/proxy sources, require Moonraker authentication, and disable or narrow shell/update-manager and system-control actions; verify ordinary Client/IoT sources cannot call the API. |
| P0 | Cosmo OTA disables certificate validation for both manifest and image and verifies no signature or digest before flashing. | `cosmo-notes/firmware/src/src/app/network.cpp`. | Fail closed on normal TLS validation and an authenticated manifest/image, with a corrupt-image test and recoverable previous firmware. |
| P0 | Docker-published ports bypass the NixOS firewall; multiple workload and management APIs still bind all host interfaces. | `desktop-nixos/docs/reference/service-exposure.md` plus every current `servarr/machines/*/*.yml` Compose publication (the `*.compose.yml` glob misses `ha-harness.yml` and the Kepler model/Whisper files). | Remove publications used only by the proxy; bind unavoidable listeners to exact LAN/tailnet addresses; enforce and test the remaining Docker ingress independently of the Nix firewall. |
| P1 | Digest pinning is broad, but ordinary Compose images are checked only for registry existence and Kindle's Trivy result is report-only. | `servarr/machines/scripts/validate-added-images.sh` and `kindle-dash/.github/workflows/ci.yml` (`exit-code: "0"`). | Reuse the changed-image set for vulnerability evidence; block newly introduced fixable critical findings after a reviewed baseline, including Kindle before promotion. |
| P1 | Security and monitoring are strong centrally but incomplete at the leaves. No fleet Wazuh agent is enrolled; Kubernetes audit evidence is not routed; some app/device security events are absent. | Current Wazuh and runtime-security proposal status. | Complete existing Wazuh retention/credential gates, then one server and one workstation canary before wider coverage. |
| P1 | Kubernetes restrictions are demonstrated in `demo`, not consistently applied per workload namespace; Traefik has one replica. | `homelab-gitops/apps/demo/*` and `platform/traefik/values.yaml`. | Apply `restricted` and default-deny per compatible namespace; use two Traefik replicas only to cover pod/worker maintenance. |
| P1 | The k3s control-plane VMs, workers, load balancer, snapshots, and storage all share Kepler. | `desktop-nixos/modules/hosts/kepler/k3s-cluster.nix`. | Label this node/VM continuity, not host HA. Keep restore proof authoritative until a second physical cluster host is approved. |
| P1 | Discovery remains the failure domain for ingress, primary DNS, OpenBao, monitoring, and several household workloads. | Fleet ownership and workload placement. | Prove secondary DNS, independent dead-man delivery, backups, and a timed Discovery recovery drill before considering active/active services. |

## Stack-wise plan

### 1. Repository and software-supply chain

**Repositories:** all entries in `repos.json` plus every private repository in
the `homelab-iac` `github/repos/terragrunt.hcl` inventory that the manifest
omits (`vault`, `ai-server`, `datafoundation-support-scripts`, `romozinha`,
`sail-dev`, `nanda_colors`); implementation owner `homelab-iac` for repository
settings and each leaf for its workflow. Any repository excluded from items
1–2 must be declared detect-only or out of scope with a rationale.

1. Change private-repository `security.yml` triggers from manual-only to PR,
   `main` push, and manual. Fix the Discord notify step's `push`-only event
   gate so PR and manual failures also notify. Keep findings inside GitHub;
   Discord receives only a redacted link.
2. Add `main` push to the existing validation workflows for `servarr`,
   `homelab-gitops`, `home-assistant-config`, and other deployment-bearing
   private repos. This is after-the-fact detection while `main` is unprotected,
   but it closes the current silent direct-push path.
3. Add Gitleaks to `homelab-iac` CI. Run a one-time full-history Gitleaks scan
   of each public repository, with documented triage and rotation of any
   finding. Retain Trivy's HIGH/CRITICAL IaC gate, pinned Actions, minimal
   `GITHUB_TOKEN` defaults, and the scoped Kindle App.
4. Reuse Servarr's existing changed-image detector to scan only added/changed
   public digests. The detector is currently gated on `pull_request` and diffs
   the PR base; give it a push-event base (`github.event.before`) or declare
   it PR-only. Start report-only, record the baseline, then fail on newly
   introduced fixable critical findings. Make Kindle's current report-only
   Trivy step a promotion gate under the same policy.
5. Enable GitHub's native secret scanning and push protection for every public
   repository through the existing `github_repository` module
   (`security_and_analysis`); it blocks pushed secrets pre-receive at no cost.
6. Evaluate GitHub Pro/Team only for high-impact private repos. Current GitHub
   documentation limits private-repository rulesets to paid plans. If approved,
   protect `servarr`, `homelab-gitops`, `homelab-iac` if ever private,
   `home-assistant-config`, `ha-harness`, `klipper-biqu`, and `cosmo-notes`
   first. If not, retain manual GitOps sync and exact-revision deploy gates; do
   not pretend CI is preventive.
7. Keep Kindle's signed image path as the reference. Do not require Cosign/SBOM
   for configuration-only or Nix package repos unless they start publishing
   executable artifacts outside Nix's locked/hashes path.

**Acceptance**

- A synthetic secret fixture fails on PR and `main` push without exposing the
  fixture in Discord.
- A direct invalid manifest/config push produces a failing check and alert.
- A changed public image records vulnerability evidence; a synthetic new
  fixable-critical finding blocks promotion after the baseline phase.
- Public protected repos still require their named status checks.
- Public repos show secret scanning and push protection enabled in the IaC
  plan, and each has a recorded, triaged full-history scan result.
- Private repos are explicitly classified as enforced or detect-only.

### 2. Internet edge and network

**Repository:** `homelab-iac`; reverse-proxy policy in `servarr`.

1. Keep zero router port forwards, UPnP disabled, and Cloudflare/Tailscale as
   outbound-only ingress. Add a drift fixture that fails on a new public
   listener, management port, origin record, or widened source range.
2. Inventory every Cloudflare Tunnel hostname. Each must map to a declared
   `fleet.services` entry, an Access policy or explicitly public webhook, and a
   rate/body/timeout budget.
3. Retain the Whisper rate limit. Add HA or webhook limits only after replaying
   real Alexa/device/webhook flows; a limit that breaks authentication or
   emergency control is not hardening.
4. For public webhooks, verify the application signature before parsing the
   body, cap body size and timeouts at SWAG, reject unused methods, and retain
   authentication failures without request bodies.
5. Execute the existing segmentation P0 first: narrow NFS, SMB, Moonraker, and
   model APIs before any VLAN canary. Then roll Clients, IoT, and Cameras one
   canary at a time with IPv4/IPv6 parity.
6. Execute UniFi IDS/IPS and the native LAN-only honeypot under the
   segmentation record, which owns that plane. Land the notify-only start and
   the per-signature promotion policy (seven observed days and a named
   response) in that record first; this document only sequences it. Do not
   deploy an Internet honeypot.

**Acceptance**

- External IPv4 and global-IPv6 scans see only declared Cloudflare edges and no
  origin or management listener.
- Direct origin requests, forged host headers, unauthenticated Access requests,
  oversized bodies, and excess requests fail as designed.
- An allowed device flow still works; an ordinary Client/IoT source cannot
  reach gateway, storage, printer-control, or workload-management APIs.
- One controlled honeypot contact and one rate-limit event reach Wazuh with
  source attribution and no payload content.

### 3. Host and cluster substrate

**Repository:** `desktop-nixos`.

1. Preserve the shared firewall, fail2ban, SSH, auditd, upgrade rollback, and
   host telemetry modules. Add source/interface tests rather than a second host
   firewall framework.
2. Re-audit current listeners from source and live state. For Docker, enforce
   the declared publication inventory through explicit binds and a
   `DOCKER-USER`/equivalent ingress policy where an unavoidable publication
   still needs source filtering.
3. Complete Wazuh canaries under the existing resource thresholds. Collect
   auth, audit, FIM, firewall, and security-control events only; keep general
   journals in Loki.
4. Add a Kubernetes API audit policy that excludes Secret request/response
   bodies and routes only high-signal authz, privileged workload, RBAC,
   admission, exec/attach, and non-GitOps mutation evidence.
5. Prove k3s restore from one control-plane snapshot after loss of a disposable
   VM. Do not call the three same-host control planes physical HA.
6. Keep Kepler and Vanguard dead-men independent of Discovery and force-fire
   each path after deployment. Deduplicate identical outages at the operator
   layer, not by adding shared infrastructure.
7. Execute the stateful record's P3 secondary-DNS gate (a LAN-reachable
   secondary fleet resolver proven with AdGuard stopped) before the
   Discovery-loss acceptance test below.
8. Refresh `docs/reference/service-exposure.md` (owned by this repository) from
   the current Servarr Compose render and live listeners after containment.
   Source and as-built tables must agree.

**Acceptance**

- A denied TCP/UDP/ICMP fixture increments bounded evidence without log flood.
- A synthetic unexpected wildcard listener alerts; stopping an expected
  listener remains an availability event.
- One SSH, sudo, FIM, audit-loss, and denied Kubernetes request fixture reaches
  the owning plane with stable host/cluster identity.
- Loss of Discovery still produces an external incident and secondary fleet DNS
  remains usable.

### 4. Compose workloads, monitoring, and Wazuh

**Repository:** `servarr`.

1. Remove host port publications used only as SWAG upstreams. First review
   Discovery `5055`, `8091`, `8642`, `8644`, `9080`, and `9696`, then Kepler's
   retrieval, tools, knowledge, model, MinIO, and Wazuh surfaces. Bind every
   retained publication to its exact interface and named consumer.
2. Narrow the HA harness port even though bearer authentication is present.
   Keep the app token mandatory and its authoritative executor allowlisted.
3. Add Compose hardening only where compatible: non-root user, dropped
   capabilities, `no-new-privileges`, read-only root, bounded writable mounts,
   resource limits, and health checks. Canary one service family; LinuxServer,
   VPN, GPU, and hardware workloads keep documented exceptions.
4. Finish the existing Wazuh gates: split API/indexer credentials, measured raw
   and alert retention, component limits, notification ownership, then agent
   enrollment.
5. Keep Prometheus/Grafana for rates/absence and Loki for broad logs. Add no
   duplicate event bus. Force-fire one security alert through native Discord
   and retain one recovery; the retired Cleytin webhook is historical only.
6. Extend Compose validation beyond registry existence: reject an undeclared
   wildcard (`0.0.0.0`/`[::]`) publication and an unpinned public image, so
   the acceptance fixtures below have an implementing check.

**Acceptance**

- Compose validation rejects an undeclared wildcard publication and an
  unpinned public image.
- Allowed proxy/tailnet consumers work; a denied LAN or container source cannot
  reach the same backend directly.
- Security component loss, telemetry blindness, backup staleness, and restore
  failure each have one owner and one actionable route.
- Wazuh and monitoring restore drills pass without production network access.

### 5. Lab Kubernetes workloads

**Repository:** `homelab-gitops`; substrate changes remain in `desktop-nixos`.

1. Keep every Argo Application manual while private `main` is unprotected.
   Sync root and children at one exact reviewed revision.
2. Label each application namespace `restricted` when the chart renders cleanly.
   Retain explicit documented exemptions; do not tighten the cluster default in
   one change.
3. Add per-namespace default-deny plus exact DNS, ingress, OpenBao, NFS, and
   telemetry flows. Start with Airflow and one platform namespace; observe
   denied flows before widening.
4. Run two Traefik replicas across the two workers with a PDB/anti-affinity only
   after resource and rolling-update tests. This covers pod or worker-VM
   maintenance, not Kepler loss.
5. Add readiness/liveness and resource requests for owned workloads missing
   them. Do not override safe upstream chart defaults merely for uniform YAML.
6. Route Kubernetes audit/security evidence once, and keep application logs in
   the existing Alloy/Loki path.

**Acceptance**

- Helm render, kubeconform, PSA, and NetworkPolicy fixtures pass.
- A forbidden privileged pod and unexpected RBAC mutation are denied/alerted;
  Secret values do not enter logs.
- Draining one worker preserves ingress during the canary. Stopping Kepler is
  documented as cluster outage and the restore procedure, not HA, is exercised.

### 6. Application and device leaves

| Repository | Security and pentest-resilience change | Monitoring/recovery change |
|---|---|---|
| `hermes-flake` / `hermes-skills` | Preserve isolation modules and read-only external skills; observe deployed policy files through host FIM, never ingest skill/session content. | Use host service health; no repo-specific agent or HA stack. |
| `home-assistant-config` | Re-derive the entire `trusted_proxies` list (drop `172.0.0.0/8` and any gateway/Tailscale entry not strictly required); test forwarded-IP spoofing; retain Cloudflare Access and dedicated MQTT identity. | Prove HA backup restore and Zigbee2MQTT watchdog recovery; no unsupported HAOS agent. |
| `klipper-biqu` | Replace broad RFC1918 trusted clients with named admin/HA/proxy sources; require Moonraker authentication; restrict shell/update-manager actions and preserve locked-while-printing behavior. | Keep config backup; force a safe service/config restore with heaters off. |
| `kindle-dash` | Retain LAN allow/deny, sensitive-volume handling, Trivy, signed image, SBOM/provenance, and consumer digest verification. | Health check plus rebuild from immutable image; no active/active renderer. |
| `opencode-flake` / `codex-flake` / `buzz-flake` | Keep locked Nix inputs, pinned Actions, build checks, and host-policy FIM. Do not collect prompts, auth, sessions, or history. | Rebuild/rollback through Nix; no runtime HA requirement. |
| `ha-harness` | Keep bearer auth and adversarial/confirmation/authoritative-executor gates; narrow its network bind and rate/size limits. Never log audio, transcript, prompt, token, or entity state. | Shadow before authority; use host/container health and a known-safe fallback conversation agent. |
| `cosmo-notes` | Validate TLS and authenticate OTA manifest/image; keep Cloudflare Access plus the existing Whisper rate limit; emit only bounded status codes. | Retain the previous firmware and prove failed-update recovery; never export note/audio content. |
| `renovate-config` | Preserve the hard repository allowlist, GitHub App token, minimum release age, digest pins, and CI-gated automerge. | Alert on runner failure; configuration is rebuildable from Git. |

## Authorized-pentest resilience gate

“Protection from pentesters” means the same controls must withstand an
authorized tester or hostile client without relying on obscurity. It does not
authorize scanning from this proposal.

Before any exercise:

1. approve exact source addresses, targets, time window, methods, rate, stop
   conditions, data handling, and operator contact;
2. exclude destructive payloads, password spraying against real users, data
   extraction, persistence, denial of service, and physical-control commands;
3. take current backups, verify rollback, create monitoring silences only for
   expected availability noise, and keep security detections active;
4. begin outside the home, then a non-admin Client/IoT source, then a non-admin
   tailnet identity. Admin credentials are a separate final exercise.

Minimum regression set:

- public DNS/origin discovery, IPv4/IPv6 listener inventory, TLS and Access
  enforcement, method/body/rate limits, and webhook signature failure;
- LAN and tailnet lateral reachability against the declared policy matrix;
- SSH auth failure/fail2ban, firewall reject/scan, UniFi honeypot, Wazuh
  attribution, and external dead-man delivery;
- unauthenticated direct access to Compose/Kubernetes backends and management
  ports;
- proxy-header spoofing against Home Assistant and physical-control denial
  against Moonraker;
- malformed HA-harness envelopes, prompt injection, replay, broad-target action,
  and confirmation bypass;
- corrupted or substituted Cosmo firmware and Kindle image provenance failure;
- secret-shaped commit, unsafe IaC fixture, privileged pod, RBAC mutation, and
  unsigned/unpinned artifact fixtures.

Pass criteria: no unexpected listener or origin bypass; no unauthorized state
change; no secret/content disclosure; bounded 401/403/404/429 behavior; every
high-signal action attributed in the owning telemetry plane; monitoring and
security pipelines recover after the exercise.

## Resilience policy: recovery before false HA

- Multiple processes, containers, VMs, disks, or etcd members on one physical
  host do not protect against that host, power, or network failure.
- Active/active is justified only when a measured outage exceeds an approved
  recovery target and a second physical failure domain exists.
- Until then, spend complexity on immutable deployment, restart policy, health
  checks, independent detection, current backups, and timed restore drills.
- Record RTO/RPO and restore owner in the existing stateful inventory. Use the
  current backup cadence as evidence, not as an assumed guarantee.
- Priority recovery order: network/DNS and admin access; OpenBao and ingress;
  monitoring/security evidence; Home Assistant and household services; lab and
  development workloads.

## Delivery order

1. **P0 trust boundaries:** private CI triggers with a working notify gate and
   IaC Gitleaks; public-repo push protection and one-time history scans; HA
   proxy allowlist; Moonraker clients and authentication; Cosmo OTA
   authentication; direct-port inventory and first unnecessary publication
   removals.
2. **P1 evidence:** Wazuh retention/credential split, one server and workstation
   agent, Kubernetes audit canary, one force-fired alert, changed-image
   vulnerability baseline then blocking with the Kindle promotion gate, and
   both external dead-man proofs.
3. **P2 containment:** existing network-segmentation P0, edge drift fixture,
   tunnel-hostname inventory, webhook signature/body/timeout hardening, one IoT
   canary, namespace-by-namespace PSA/NetworkPolicy, then remaining direct-port
   cleanup.
4. **P3 recovery:** timed Discovery, OpenBao, Wazuh, k3s, HA, printer-config,
   and Cosmo failed-update drills. Add two-replica Traefik only for worker/pod
   maintenance.
5. **P4 authorized exercise:** run the bounded regression set, close findings
   leaf-first, and repeat only the failed paths.

Each phase stops if rollback, evidence attribution, or an allowed user flow
fails. Land leaf changes first, update consumers, then deploy one canary.

## Explicitly deferred

- A second SIEM, metrics/logging stack, ingress controller, service mesh, or
  policy engine.
- CrowdSec, Suricata, Zeek, OpenCanary, Cowrie, T-Pot, country blocking, learned
  anomaly detection, and automatic host isolation without a measured gap.
- Full active/active Discovery, OpenBao, monitoring, or household workloads
  before a second physical failure domain and approved RTO require it.
- Continuous aggressive scanning, Internet-facing honeypots, password spraying,
  malware collection, and any pentest without explicit scope approval.
- Uniform container hardening that breaks VPN, GPU, hardware, or LinuxServer
  workloads; exceptions remain named and tested.

## Next gate

Prepare isolated leaf changes without deployment: automatic private-repo
security/validation triggers with a working notify gate, `homelab-iac` Gitleaks
plus public-repo push protection and one-time history scans, re-derived Home
Assistant trusted proxies, authenticated and narrowed Moonraker, and
authenticated Cosmo OTA.
In parallel, render a current host-port inventory and classify every publication
as remove, bind, or documented exception. Review diffs and allowed/denied test
fixtures before any live canary.

## External constraint

GitHub documents rulesets as available for public repositories on GitHub Free
and for public/private repositories on GitHub Pro, Team, and Enterprise Cloud:
<https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository>.
The paid-entitlement decision is optional; automatic push/PR checks are not.
