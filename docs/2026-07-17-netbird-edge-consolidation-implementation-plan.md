# NetBird edge consolidation implementation plan

**Status:** Proposed · **Date:** 2026-07-17 · **Primary owner:** `homelab-iac`

## 1. Decision

Do not plan a single hard cutover that deletes both SWAG and AdGuard.

NetBird can replace a large part of SWAG's HTTP ingress role, but the
self-hosted Reverse Proxy is beta and requires a NetBird proxy cluster behind
Traefik. The change therefore replaces one edge stack with another; it does not
make the edge disappear.

NetBird cannot replace AdGuard's LAN-wide recursive/forwarding DNS and filtering
role. NetBird DNS configures only enrolled peers and forwards queries to
nameservers or serves custom private zones. It does not provide the blocklists,
safe-browsing policy, query controls, exporter contract, or DHCP-advertised LAN
resolver used by unmanaged household and IoT devices.

The target is:

1. retain AdGuard as the filtered resolver for the physical LAN;
2. move NetBird peers' private service records from AdGuard forwarding to a
   NetBird-managed custom DNS zone;
3. pilot NetBird Reverse Proxy beside SWAG;
4. migrate compatible private ingress one service class at a time;
5. consider SWAG retirement only after the beta feature, host substrate, and
   complete service inventory pass explicit gates.

## 2. Capability boundary

| Current responsibility | NetBird replacement | Decision |
|---|---|---|
| HTTPS termination and HTTP reverse proxy | Reverse Proxy HTTP services | Pilot, then migrate compatible services |
| Host and path routing | Reverse Proxy targets and paths | Pilot |
| WebSocket applications | Expected through HTTP proxying, but must be proven per app | Compatibility gate |
| Private access restricted to overlay members | NetBird-Only Access and policies | Preferred target |
| Public access with SSO/password/header auth | Reverse Proxy authentication | Pilot; keep Cloudflare edge until parity is proven |
| Access logs and CrowdSec restrictions | Proxy events and CrowdSec integration | Validate retention, alerting, and IaC coverage |
| Wildcard/public certificates | NetBird proxy ACME or static wildcard certificates | Pilot on a separate domain |
| NetBird management/signal/relay frontend | Traefik remains required for the self-hosted proxy feature | Host-substrate prerequisite |
| LAN DNS on port 53 | No | Keep AdGuard |
| Ad/tracker/threat filtering | No | Keep AdGuard |
| DNS for devices without a NetBird client | No | Keep AdGuard |
| Private DNS records for enrolled peers | Custom DNS zones and records | Migrate from AdGuard forwarding |
| DNS rewrites used by the whole LAN | Only for enrolled peers | Keep the LAN copy in AdGuard |

## 3. Target ownership

`homelab-iac` owns the desired edge objects:

- NetBird custom DNS zones and records;
- Networks, resources, routing peers, groups, and policies;
- Reverse Proxy custom domains and services;
- Cloudflare DNS records required by the proxy cluster;
- provider credentials, encrypted state, drift detection, and apply order;
- the migration catalog mapping each hostname to its exposure and auth class.

`desktop-nixos` owns host substrate:

- NetBird server/proxy and Traefik containers or services;
- host ports, firewall, persistent state, certificates mounted from secrets,
  health checks, upgrade rollback, and runtime alerts;
- NetBird clients that act as routing peers.

`servarr` owns workloads:

- application containers and backend ports;
- app-specific trusted-proxy settings;
- removal of SWAG configuration only after the IaC service is green and the
  rollback window has closed.

No repo reads another working tree at apply time. Shared host, domain, and
service facts remain published and pinned artifacts.

## 4. Proposed IaC shape

Add four bounded NetBird units:

1. **DNS zones** — one private zone for the homelab namespace, distributed only
   to approved peer groups, with explicit A/AAAA/CNAME records and a controlled
   wildcard where necessary.
2. **Networks** — narrow `/32`, domain, or wildcard resources plus redundant LAN
   routing peers. Avoid advertising the whole LAN until a specific consumer
   requires it.
3. **Proxy domains** — the custom pilot domain bound to the self-hosted proxy
   cluster. Cloudflare records point the base and wildcard names to the proxy
   ingress without proxying protocols that require direct TLS.
4. **Proxy services** — typed service definitions containing domain, targets,
   paths, host-header behavior, redirect rewriting, authentication class, and
   enabled state.

Each unit receives group and resource IDs through explicit reviewed inputs,
matching the repository's current no-cross-state-dependency convention. State
keys are added to the state-key contract before first init.

The provider stays exactly pinned. Reverse Proxy and custom DNS resources are
covered by disposable module tests before touching the live account.

## 5. Service classification

Inventory every SWAG virtual host into one class before implementation:

| Class | Examples of required behavior | Initial action |
|---|---|---|
| Private, simple HTTP | One backend, no special headers | First pilot |
| Private, authenticated UI | Identity headers, trusted proxy, redirects | Second pilot |
| WebSocket or long-lived stream | Upgrade headers and long timeouts | Dedicated compatibility test |
| Public browser application | Anonymous or SSO access, abuse controls | Keep Cloudflare/SWAG until parity |
| Machine-to-machine endpoint | Bearer/header auth and stable status codes | Dedicated contract test |
| Raw TCP/UDP/TLS | Non-HTTP protocol and explicit public port | Defer until L4 exposure is designed |
| Bootstrapping dependency | NetBird, PocketID, state backend, DNS | Never migrate first |
| LAN-only plain HTTP | Device cannot join overlay or validate modern TLS | Keep local path until proven |

The catalog records owner, current hostname, backend, protocol, exposure,
authentication, special proxy directives, health probe, rollback URL, and
whether the service may be public.

## 6. Execution phases

### Phase 0 — freeze and measure

1. Export a value-free inventory of SWAG hosts and NetBird/AdGuard IaC objects.
2. Record current DNS, TLS, latency, HTTP status, WebSocket, and public/private
   reachability baselines.
3. Confirm the NetBird server version supports proxy clusters and custom DNS.
4. Confirm the provider pin exposes DNS zone, DNS record, proxy domain, and
   proxy service resources against the live management API.
5. Produce plans for all existing NetBird and AdGuard units; require no drift.

**Gate:** no migration begins with unexplained drift or an incomplete hostname
catalog.

### Phase 1 — provider and module contracts

1. Add typed modules for custom DNS, proxy domains, and proxy services.
2. Add variable validation for FQDNs, protocols, target types, paths, and
   mutually exclusive authentication modes.
3. Mark passwords, PINs, tokens, and provider responses sensitive.
4. Add import blocks or documented import IDs for any object created during a
   bootstrap probe.
5. Extend drift checks and state-key fixtures.
6. Run format, validate, lint, render, and disposable lifecycle tests.

**Gate:** tests prove create/read/update/delete and a second plan is no-op.

### Phase 2 — remove AdGuard from the NetBird peer DNS path

1. Create the private homelab DNS zone in NetBird.
2. Copy only service records required by NetBird peers; do not copy filtering
   policy or public records.
3. Distribute the zone to canary peer groups.
4. Test exact, wildcard, negative, and search-domain answers on LAN and off-LAN.
5. Compare answers with AdGuard during a bounded dual-answer period.
6. Once equal, remove the NetBird nameserver rule that forwards the homelab zone
   to AdGuard.

**Gate:** canary peers resolve and reach services off-LAN while AdGuard remains
the unchanged resolver advertised by UniFi DHCP.

### Phase 3 — establish proxy substrate

This phase requires a paired `desktop-nixos` change, but its control objects and
acceptance contract live here.

1. Deploy Traefik for TLS passthrough in front of the self-hosted NetBird
   endpoints.
2. Deploy at least one `netbird-proxy` instance with a dedicated token and
   persistent identity.
3. Add a second proxy instance or document why the pilot temporarily accepts a
   single failure domain.
4. Configure a separate pilot domain and wildcard DNS.
5. Verify management, signal, relay, PocketID, and existing peers before adding
   any application service.

**Gate:** control-plane and peer connectivity remain green through proxy and
Traefik restarts. SWAG remains untouched.

### Phase 4 — three-service pilot

Migrate one low-risk service from each relevant class:

1. simple private HTTP;
2. authenticated private UI;
3. WebSocket or machine-to-machine endpoint.

Create new pilot hostnames. Do not move production names yet. Require:

- valid TLS;
- correct host and forwarded headers;
- correct redirects;
- application health and authentication;
- access-policy denial from an unauthorized peer;
- observable proxy events;
- success through direct and relayed NetBird paths;
- stable behavior after proxy, routing-peer, and management restarts.

**Gate:** seven consecutive days without functional or certificate regression.

### Phase 5 — production hostname migration

1. Migrate private services in small batches.
2. Lower DNS TTL before each batch.
3. Keep the SWAG virtual host and previous DNS answer available but inactive.
4. Switch the production record to the NetBird proxy domain.
5. Run service-specific smoke tests and a second no-op plan.
6. Restore the old record immediately on any auth, WebSocket, header, or latency
   regression.

Public Cloudflare Tunnel services remain on their existing edge until NetBird's
public authentication, abuse controls, availability, and rollback behavior
match the current contract.

### Phase 6 — SWAG retirement decision

Do not remove SWAG merely because most private hosts migrated. Retirement needs:

- NetBird Reverse Proxy out of beta, or an explicit accepted-beta decision;
- two healthy proxy instances in separate failure domains;
- every SWAG host classified and migrated or intentionally retired;
- NetBird/PocketID bootstrap independent of SWAG;
- public Cloudflare paths migrated or assigned another supported origin;
- certificate renewal, access logs, CrowdSec, alerts, and backups proven;
- no remaining plain-HTTP/LAN-only or custom-nginx consumer;
- fourteen-day rollback window after the final hostname.

If any condition fails, keep a minimal SWAG deployment for the exceptions.

### Phase 7 — AdGuard reduction, not retirement

After the NetBird custom zone is stable:

1. remove only overlay-specific forwarding and duplicate peer-only rewrites;
2. retain LAN wildcard/service rewrites required by non-peer devices;
3. retain upstream DNS, filtering lists, safe-browsing controls, query/stat
   policy, runtime state, exporter, and port 53;
4. require DNS/API/exporter smoke tests and a second no-op plan after every
   reduction.

AdGuard retirement is out of scope unless UniFi or another dedicated resolver
first replaces all LAN DNS and filtering behavior.

## 7. Security and availability gates

- Default-deny remains active; no implicit all-to-all policy may reappear.
- Peer approval is enabled before adding standing setup keys.
- Routing resources prefer `/32` or named domains over a LAN-wide route.
- Proxy credentials are separate from the Terraform PAT and rotate
  independently.
- Secrets enter encrypted state or the runtime secret store; plans and logs
  never print them.
- Public services require an explicit exposure declaration. Missing exposure
  means private.
- The proxy cannot become the only path to its own management recovery.
- DNS continues working for LAN devices during every phase.
- No SWAG config, AdGuard state, volume, or runtime data is removed before the
  replacement path is green and its second plan is no-op.

## 8. Rollback

Rollback is DNS-first and non-destructive:

1. disable the affected NetBird proxy service;
2. restore the previous DNS record or Cloudflare tunnel origin;
3. re-enable the preserved SWAG virtual host;
4. confirm application, DNS, certificate, and authentication health;
5. retain the failed NetBird objects disabled for evidence;
6. fix forward and require a new pilot window.

AdGuard rollback restores the previous nameserver-group forwarding rule. Its
container, runtime state, filters, and DHCP advertisement never leave during
this plan.

## 9. Completion criteria

The plan is complete when:

- NetBird peers resolve the private zone without querying AdGuard;
- at least three service classes run through IaC-managed NetBird proxy services;
- every migrated service has a tested rollback and a second no-op plan;
- public and private exposure are explicitly classified;
- AdGuard continues serving filtered LAN DNS with no regression;
- a recorded decision either retires SWAG, keeps a minimal exception proxy, or
  stops further migration while Reverse Proxy remains beta.

## 10. External constraints

- [NetBird Reverse Proxy](https://docs.netbird.io/manage/reverse-proxy) is beta
  and requires Traefik for self-hosted TLS passthrough.
- [NetBird DNS](https://docs.netbird.io/manage/dns) manages enrolled peers and
  forwards or serves their queries; it does not replace LAN DHCP/DNS.
- The official provider exposes
  [`netbird_reverse_proxy_service`](https://registry.terraform.io/providers/netbirdio/netbird/latest/docs/resources/reverse_proxy_service)
  plus custom DNS zone and record resources, but remains pre-1.0 and exactly
  pinned.

