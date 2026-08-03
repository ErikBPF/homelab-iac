# Self-hosted NetBird overlay — resilient control plane on discovery + voyager

**Status:** Partially implemented — the Discovery control plane and public relay
pair on Voyager and Vanguard are live and source-managed as of 2026-08-02;
laptop CLI enrollment is proven. Remaining: broader fleet enrollment. Dashboard
passkey login is deferred on the upstream callback incompatibility. All gates
were ruled 2026-07-10; build/as-built is tracked in the implementation plan and
implemented records.

> Scaffold for human judgment. Facts, ports, and NixOS/Terraform surfaces are
> researched and cited. Three scoping decisions locked in §1; **all 11 detailed
> gates ruled (§11)** on 2026-07-10. Design survived three adversarial passes
> (party + red/blue-team + infra/HA); every design-changing finding is folded in.
> Live implementation record plus the reviewed decision scaffold for the
> remaining fleet rollout.

## 1. Locked decisions

Answered before drafting; they frame everything below.

| # | Decision | Choice | Consequence |
|---|----------|--------|-------------|
| L1 | Relationship to Tailscale | **Coexist now, study transition** | NetBird stands up as a second, fully self-sovereign overlay alongside Tailscale (untouched: OAuth+sops, discovery subnet-router, ACL/DNS in `homelab-iac`). Both run in parallel; a **transition plan** (§13) tracks the criteria under which NetBird *could* later supersede Tailscale — decided on evidence, not now. |
| L2 | Voyager data-plane exposure | **Expose the relay on voyager** | Oracle security-list (Terraform) opens **only port 443 (TCP-WSS + UDP-QUIC)** on voyager's public IP — the relay's single port. STUN is **not** self-hosted (§6b-H1); it's externalized, so no UDP/3478. This is the **only** public surface in the whole design (§5). |
| L3 | Identity provider | **PocketID** | Passkey-only self-hosted OIDC (mandatory WebAuthn, phishing-resistant), tiny footprint, runs on discovery beside the control plane. |

> **Post-research revision (2026-07-10):** the original draft put the admin/API
> plane behind a Cloudflare Tunnel. Research (§4, §5) showed that is unnecessary:
> every NetBird peer is already on the tailnet, NetBird's management URL is just a
> config value with **no public-reachability requirement**, and a relay validates
> tokens **offline** (no route to management needed). So the entire control plane
> goes **tailnet-only behind the existing SWAG wildcard** — the Cloudflare Tunnel
> admin hostname is **removed**. Only voyager's relay/STUN UDP is public. Voyager's
> ephemeral-IP problem is solved by a **free Oracle reserved public IP**, not DDNS.

## 2. Motivation & goals

NetBird is a self-hosted, WireGuard-based overlay with its own coordination
plane (management + signal + relay + IdP). Standing it up gives the fleet a
**self-sovereign mesh with no dependency on a third-party coordination cloud** —
complementary to the existing Tailscale mesh, not a replacement (L1).

**Goals**

- G1 — Self-hosted control plane, IaC-managed end to end (services in
  `desktop-nixos`, policy in `homelab-iac`), matching the D9 publish-and-pin /
  SSOT-per-fact model.
- G2 — **Resilience within OSS limits**: survive a single-relay loss and a
  home-uplink outage for the data path; survive a control-plane host loss for
  *existing* tunnels.
- G3 — **Fully secure by default**: default-deny ACLs, peer approval, OIDC +
  scoped setup keys, minimal public surface, no plaintext secrets in git.

**Non-goals**

- N1 — Active-active management/signal HA. That is a NetBird **Enterprise**
  feature (§7); OSS gets single-management + multi-relay + client
  tunnel-survival, and this RFC designs to that honestly.
- N2 — Retiring Tailscale (L1).
- N3 — Running the control plane on voyager. Voyager is 1 OCPU / **1 GB RAM**,
  ~51% disk, under a **$1 Oracle budget alarm**, and already flagged too weak
  for Alloy — it hosts *only* the lightweight relay (§4).

## 3. Component model (researched facts)

NetBird self-host, current topology (native WS/QUIC relay, post-v0.29; combined
server post-v0.65). Cited from `docs.netbird.io`.

| Component | Role | State | Public? | Notes |
|-----------|------|-------|---------|-------|
| **Management** | Control plane: peer registration/auth, network map, IP mgmt (`100.64.0.0/10`), ACL/DNS/routes, activity log. REST `/api/*` + gRPC. | **Stateful** — SQLite default; **PostgreSQL** for scale/backup. Holds all network state + peer WG **public** keys (never private). | via reverse proxy :443 | SQLite→Postgres is the only OSS scaling/HA lever. |
| **Signal** | Connection-negotiation relay (ICE candidates). gRPC + WS. | **Stateless**; messages are point-to-point encrypted — signal can't read them. | via reverse proxy :443 | Rarely needs extraction in OSS. |
| **Relay** (native) | Fallback data path when P2P fails. Forwards **already-WireGuard-encrypted** packets (`rels://`). | Effectively stateless (in-memory sessions). | **Yes (voyager :443)** | QUIC (**UDP**) + WebSocket/TCP, **sharing one port 443**. HMAC-authed via `NB_AUTH_SECRET`; no built-in rate limits (→ §6b). |
| **STUN** | NAT discovery (server-reflexive candidates). Embedded in relay, **opt-in, off by default**. | Stateless | **Not self-hosted** | Externalized to `stun.netbird.io`/Google/Cloudflare (§6b-H1) — the embedded one is an un-mitigated open reflector, so we don't run it. |
| **Dashboard** | React admin UI → Management REST. | Stateless | via reverse proxy :443 | Human-facing. |
| **PocketID (IdP)** | OIDC login for users; issues the JWTs Management trusts. | Stateful (small) | via reverse proxy :443 | L3. Machine enrollment uses setup keys but the IdP must still exist for the account/admin. |

*(Ports: internal backends 8080/8081/8084/10000 behind one proxy post-v0.65;
older guides show 33073/33080/80 — match the deployed tag.)*

**What a peer must reach, and over what path:** Management + Signal + Dashboard +
IdP are a single TCP **443** surface behind one reverse proxy — but "reachable by
the peers," **not** "public." NetBird's management URL is a plain config value
with no Internet-reachability requirement ([selfhosted-guide](https://docs.netbird.io/selfhosted/selfhosted-guide));
since every peer is already on the tailnet, this 443 surface is served
**tailnet/LAN-only** via SWAG (§4–5). The relay's data surface — **port 443
(WSS/TCP + QUIC/UDP, one port)** — must be raw and cannot be reverse-proxied or
tunneled; that is the only piece that is genuinely public, and it lives on
voyager. **STUN is externalized** (§6b-H1), so no UDP/3478 is self-hosted.

> **Relay ↔ management is decoupled.** A relay validates the client's HMAC token
> **offline** against its static `NB_AUTH_SECRET` (`TimedHMACValidator`) — it never
> calls management. Management mints the token, the relay validates it locally. So
> the public voyager relay needs no route to the tailnet-only management at all
> ([external-relays](https://docs.netbird.io/selfhosted/maintenance/scaling/set-up-external-relays)).

Sources: [how-netbird-works](https://docs.netbird.io/about-netbird/how-netbird-works),
[ports-and-firewalls](https://docs.netbird.io/about-netbird/ports-and-firewalls),
[selfhosted-guide](https://docs.netbird.io/selfhosted/selfhosted-guide),
[external-reverse-proxy](https://docs.netbird.io/selfhosted/external-reverse-proxy),
[set-up-external-relays](https://docs.netbird.io/selfhosted/maintenance/scaling/set-up-external-relays).

## 4. Placement (forced by the host facts)

```
        INTERNET (only voyager relay is publicly reachable)          external STUN
                              │                                    (stun.netbird.io /
                    voyager RESERVED public IP (:443 only)          google / cloudflare)
                    static, survives recreate; public DNS A               ▲
                              │                                           │ srflx
   ┌───────────────────────┐ │        ┌────────────────────┐            │ discovery
   │  DISCOVERY (x86, 24/7) │ │        │ VOYAGER (1 vCPU/1GB)│           (no self-hosted
   │  control plane + relay#1        │ │  relay#2 (no STUN)  │            STUN → no UDP/3478)
   │───────────────────────│         │────────────────────│
   │ • management (Postgres)│        │ • netbird relay     │
   │ • signal               │        │   (~16 MB Go bin)   │
   │ • dashboard            │        │ • :443 WSS(tcp)     │
   │ • PocketID (OIDC)      │        │   + QUIC(udp)       │
   │ • relay #1             │        │ • metrics/health →  │
   │ • SWAG (wildcard cert) │        │   tailnet0 only     │
   └───────────┬────────────┘        │  Oracle SL: 443 only│
               │                     │  nftables rate-limit│
               │                     └──────────┬──────────┘
     TAILNET-ONLY 443 (SWAG)                    │ public relay path
     nb.<zone>/id.<zone> resolve                │ (failure-domain-independent)
     to discovery over the existing             │
     Tailscale mesh + subnet route              │
               └──────────────┬─────────────────┘
                     FLEET PEERS (services.netbird.clients.*)
              control plane over tailnet ▸ data plane: P2P (srflx via external
              STUN) ▸ fall back to relay#1 (tailnet) or relay#2 (public voyager)
```

**Why this split is essentially forced, not chosen:**

- **Control plane → discovery, tailnet-only.** Management is stateful and wants
  Postgres + backup + a reverse proxy + an always-up container runtime. Discovery
  already runs **rootful Docker**, a **Postgres** (`infra` stack), and **SWAG**
  (wildcard `*.homelab.pastelariadev.com` via Cloudflare DNS-01). It's the 24/7
  hub. The 443 surface (`nb.<zone>`, `id.<zone>`) is served **only over the
  tailnet/LAN**: off-LAN peers already reach discovery `.210` through the existing
  Tailscale subnet route + resolve the wildcard via AdGuard/MagicDNS split-DNS, so
  the existing wildcard cert works with **zero new public exposure** and no CF
  Tunnel. TLS is standard — NetBird does no cert pinning; the proxy only needs
  HTTP/2 + gRPC, which nginx/SWAG provides.
- **Relay → both.** The relay is a ~16 MB stateless static Go binary
  (`netbirdio/relay`, multi-arch incl. arm64/amd64); idle RAM is tens of MB. It
  fits voyager's 1 GB trivially. Two relays = the OSS resilience move (§7): clients
  health-check the configured relays and fail over. **Discovery relay** is
  advertised on an **internal** name (split-DNS → tailnet/LAN) for on-net peers;
  **voyager relay** on a **public** name (below) so it stays reachable even when
  the home uplink/DNS is down — the failure-domain-independent path.
- **Public STUN/QUIC → voyager.** Voyager is a cloud VM in a **different failure
  domain** with a public IP and a Terraform-managed security list — exactly what a
  public relay/STUN endpoint should be. Discovery sits behind home NAT, so its
  relay serves LAN + tailnet peers only.

**Voyager IP — solved at the source.** Oracle Always-Free includes **1 reserved
(static) public IP** at no charge; it survives instance recreate/terminate (the
current IP is *ephemeral* and would move). Convert voyager to a reserved public IP
in the `oracle` Terraform unit (`oci_core_public_ip lifetime="RESERVED"` attached
to the primary private IP) → the address is permanent. A **public** Cloudflare
**DNS-only** (grey-cloud, since Cloudflare's proxy can't carry UDP) A record
`relay.<zone> → voyager` then never needs updating. NetBird advertises the relay
by hostname (`rels://relay.<zone>:443`) with **no IP baked in**, so DNS fully
decouples it regardless. *(Fallback if the reserved IP is ever unviable:
`services.ddclient` with `protocol="cloudflare"`, token via sops `passwordFile` —
kept as a documented backup, not the plan.)*

## 4a. Second OCI VM — control-plane resilience (fixes the grill's SPOF)

The grill's finding #2 (single management + 24 h `credentialsTTL` fuse, §7) and
the concentration risk of putting everything on discovery both point at the same
gap: **management is a single point of failure.** A second free Oracle VM closes
it. Hard constraints first (researched):

- **Only 1 free *reserved* public IP per tenancy** — voyager holds it (§4). A
  second VM gets an **ephemeral** IP → its relay is advertised by a hostname kept
  fresh by **`services.ddclient` (cloudflare)** (the fallback from §4 becomes the
  *primary* mechanism here).
- **São Paulo is single-AD** → no cross-AD separation is possible on free tier; the
  best achievable is a **different Fault Domain** (separate power/hardware within
  the AD). Real, but modest — honestly not a true geo-DR.
- **A1 free pool was cut to 2 OCPU / 12 GB** (≈June 2026, free tier) and A1
  capacity in sa-saopaulo-1 is **chronically unavailable** — telstar has logged
  586 failed creates (`telstar RFC:81-96`). A 2nd **AMD micro (1 GB, x86)** is
  provisionable *now*; an A1 is a capacity lottery.

**Two-track plan, sequenced by what's actually obtainable:**

**Track 1 — now, a 2nd AMD micro (or reuse when convenient):** stand it up in a
**different Fault Domain** as (i) **relay #3 / offsite Postgres read-replica**. The
replica turns DR restore from "restore a snapshot" into "promote a warm replica" —
**RTO shrinks from hours to minutes, well under the 7 d TTL.** 1 GB comfortably
hosts a relay + a streaming replica; it does **not** host the full control plane.
This is the concrete, immediately-available resilience win and directly retires the
grill's #2 severity.

**Track 2 — when an A1 (telstar) provisions:** the 2 OCPU / 12 GB A1 *can* host the
**full control plane** (management + signal + dashboard + PocketID + Postgres;
arm64 images exist — pin-verify per component). Use it as a **warm-standby
management**: Postgres streaming replication from discovery's primary, standby
containers idle, **promote manually** (promote replica → start management → flip the
`nb.<zone>` DNS record). **Honest limits:** OSS has **no active-active, no automated
failover, no endorsed standby recipe** — multi-instance management/signal HA is
**Enterprise-only**. This is a DIY active-passive pattern the OSS *supports* but
doesn't bless. And **telstar is deliberately public-facing / off the home LAN**
(`telstar RFC`, offsite-DR doc) — hosting control-plane state + PocketID + the
setup-key-signing DB there is a **threat-model change** that needs a deliberate call
(§11-Q11), not a default. A **relay** on telstar fits its profile cleanly (data-plane
only, no secrets at rest); a **full standby management** does not, without that call.

> **Split-brain is the DIY-HA footgun (infra fix).** Manual promote + DNS flip +
> streaming replication has **no fencing** — flip during a *partial* partition
> (tailnet down but discovery's management still alive) → two managements writing
> two Postgres → divergent maps + corruption on failback. So promotion is a
> **one-way, human-gated runbook: confirm the primary is dead / demote it (STONITH)
> *before* promoting the replica.** Never automate it. And the `nb.<zone>` record
> carries a **low TTL (~60 s)** from day one so the DR flip actually propagates in
> minutes (the RTO<TTL claim, §7) instead of waiting out a default TTL + peer
> `resolved` caches — measured, not assumed, in the §10 drill.

> **Net:** Track 1 kills the SPOF severity cheaply and now; Track 2 is the fuller
> answer but gated on Oracle capacity and a threat-model decision. Neither requires
> Enterprise; both stay within Always-Free. **The Track-1 2nd VM is `vanguard`** —
> the second free AMD micro — specified as a multi-role offsite node in
> [`2026-07-10-vanguard-second-oracle-node.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-10-vanguard-second-oracle-node.md)
> (relay#2 + PG replica here, plus secondary DNS + dead-man's-switch + optional Vault
> Raft witness). Track 2's full-standby management stays the A1/`telstar` path.

## 4b. Addressing — NetBird overlay CIDR (fixes the 100.64/10 collision)

The grill's finding #3 is real: NetBird defaults its overlay to **`100.64.0.0/10`**,
which is **exactly** Tailscale's CGNAT block — dual-homed fleet hosts would carry two
interfaces both claiming a `100.64/10` route → ambiguous routing. NetBird does **not**
require CGNAT space (the peer range is a management-side config value accepting any
RFC1918 CIDR), so we assign it a disjoint block.

A fleet CIDR audit enumerated every range in use — LAN `192.168.1/24` + `192.168.10/24`,
Tailscale `100.64.0.0/10` (whole block), Oracle VCNs `10.0/16` + `10.1/16`, k3s
`10.42/16` (pods) + `10.43/16` (svc), voyager podman `10.88/16`, kepler MicroVM
`10.250/24`, Docker's `172.16/12` auto-pool. **Decision: NetBird overlay =
`10.100.0.0/16`** — demonstrably free, memorable, well clear of everything above and
of Tailscale's `100.64/10`.

- **Routing:** NetBird's `wt0` carries `10.100.0.0/16`; `tailscale0` keeps `100.64/10`.
  No shared prefix → no ambiguity. Verify per dual-homed host with `ip route get` to
  both an `10.100.x` and a `100.64.x` target (Phase-5 gate, §10).
- **DNS:** Tailscale MagicDNS owns `*.<tailnet>.ts.net`; give NetBird its **own**
  management DNS domain (e.g. `*.netbird.internal`) so `services.resolved` split-DNS
  routes each overlay's domain to its own resolver — no collision. NetBird needs
  `services.resolved.enable = true` (already implied by its client module).
- **SSOT:** record **both** allocations (`tailscale = 100.64.0.0/10`,
  `netbird = 10.100.0.0/16`) as a `fleet.overlays` fact in `modules/meta.nix` →
  `fleet.json`, so `homelab-iac` and any future host reads one source and no one
  re-collides the space.
- **Bootstrap must not depend on discovery's DNS (infra fix).** `nb.<zone>` resolves
  via **AdGuard on discovery** — but management *lives* on discovery, so a cold boot
  or discovery-down can't resolve the management hostname to reconnect: a
  chicken-and-egg loop. Pin the client's management URL to an address reachable
  **without discovery's resolver** — discovery's **tailnet IP** directly, or a static
  `networking.hosts`/`/etc/hosts` entry shipped by the client module — so NetBird
  bootstrap never depends on the host it manages being up to resolve it. (When the
  Track-2 standby exists, the management name is what the DR DNS-flip repoints;
  the client should therefore use a name with a **low TTL**, §4a/§10, not a
  hard-coded IP — reconcile the two: hosts-entry for the *primary* address as a
  resolver-independent floor, DNS name for failover mobility.)

## 5. Public surface & exposure posture (L2)

| Surface | Reachable by | How | Exposure | Control |
|---------|--------------|-----|----------|---------|
| Management API / gRPC | peers (on tailnet) | `nb.<zone>` → split-DNS → discovery `.210` (tailnet/subnet route) → SWAG → mgmt:8081 | **tailnet/LAN only, no public** | OIDC/JWT + scoped setup keys + peer approval |
| Signal | peers (on tailnet) | same host → signal:10000 | tailnet/LAN only | point-to-point encrypted |
| Dashboard + PocketID | admin browser (on tailnet) | `nb.<zone>` / `id.<zone>` over tailnet → SWAG | tailnet/LAN only | passkey OIDC (§6) |
| **Relay** | any peer, incl. off-net | `relay.<zone>` → **voyager reserved public IP** | **public: port 443 only (WSS/TCP + QUIC/UDP)** | Oracle SL locked to 443 only; nftables rate-limit (§6b); HMAC `NB_AUTH_SECRET`; payload is E2E-WireGuard ciphertext the relay can't decrypt |
| STUN | any peer | **external** (`stun.netbird.io` / google / cloudflare), listed in mgmt `Stuns:` | **none self-hosted** | §6b-H1 — no open reflector on voyager |

**Net exposure added to the fleet: one thing — port 443 on one cloud VM whose
entire purpose is to be reachable.** Nothing new is opened on the
home network or the UDM, and the admin/coordination plane never touches the
internet. This is *stronger* than the original CF-Tunnel design: the management
API — the crown jewel — is unreachable except from a device already authenticated
onto the tailnet.

**Two documented caveats (verify in Phase 1, §10):**

- Private-only management is *inferred* from NetBird's plain-URL design and the
  absence of any public-reachability mandate — docs never explicitly bless it.
  Prove it with a real off-LAN-on-tailnet peer before relying on it.
- **Bootstrap coupling:** a brand-new device must join **Tailscale first**, then
  enroll in NetBird. Acceptable under coexist (Tailscale is permanent, L1), but it
  means NetBird cannot bootstrap a peer that has no tailnet path.

> **Relay TLS (Q3, ruled).** Discovery relay: behind SWAG under the wildcard cert —
> no new cert. Voyager relay: terminates its own TLS for `relay.<zone>` via NetBird
> relay's **built-in Let's Encrypt** (`NB_LETSENCRYPT_DOMAINS`/`_EMAIL`/`_DATA_DIR`)
> — fewest moving parts on the offsite host.

## 6. Security model

- **Peer auth** — two paths, both used: **OIDC/JWT** (PocketID) for interactive
  users, **setup keys** for machines (reusable/one-off/ephemeral, group-scoped,
  usage-limited). WireGuard **private keys never leave the peer**; Management only
  ever sees public keys.

### 6a. MFA (where it actually lives)

NetBird self-host with external OIDC has **no MFA layer of its own** — no
"require MFA" account toggle, and MFA is **not** one of the posture-check
dimensions (those cover client/OS version, geo, network CIDR, EDR-process
presence). **MFA is 100% delegated to the IdP.** So on this stack:

> **Invariant (decided):** MFA applies to **user-facing devices only** — laptops,
> desktops, phones — which enrol **interactively (SSO)** and therefore traverse
> PocketID's passkey. **Fleet servers/appliances enrol via setup key** and are
> exempt from user MFA *and* from login-expiration **by construction** (a machine
> is not a user login). This is deliberate: it also resolves the grill's
> §6a↔§7 contradiction — an always-on fleet host never hits a login-expiry during
> an outage, because it never had one. Only human devices re-auth.

- **PocketID is passkey-only** — WebAuthn/FIDO2 is the *mandatory, sole* primary
  factor. There is no password and no weaker method to fall back to, so login is
  inherently phishing-resistant and passwordless. Interactive `netbird up` (no
  setup key) runs the OIDC flow → hits PocketID → requires the passkey.
- **Setup-key (machine) enrollment bypasses user MFA** — by design; a machine is
  not a user login. Keep machine setup keys **ephemeral + usage-limited +
  group-scoped**, and gate joins with **peer approval** so a leaked key can't
  silently add peers.
- **Force periodic re-auth (user devices only)** — set **SSO login-expiration** on
  human/SSO peers so they re-run the OIDC flow (re-hitting the passkey) on a
  schedule. This is the only NetBird lever that re-asserts MFA over time. Fleet
  setup-key peers are exempt (and must be — see the invariant above), so this never
  affects data-plane resilience.
- **Login-code recovery kept (Q6, ruled).** PocketID's **one-time login code**
  (sign in without your passkey) stays **enabled** — a deliberate out-of-band
  recovery path, accepted precisely to avoid the single-admin self-brick the grill
  flagged (lost passkey + tailnet-only + no fallback = locked out of your own
  control plane). It's a known, bounded bypass; treat the login-code issuance as a
  tier-0 admin action.

Sources: [NetBird MFA](https://docs.netbird.io/manage/settings/multi-factor-authentication),
[identity-providers](https://docs.netbird.io/selfhosted/identity-providers),
[PocketID](https://pocket-id.org/).

### 6b. Voyager public-relay hardening (abuse resistance on a standing IP)

A permanent public IP on a 1 vCPU / 1 GB VM under a **$1 budget alarm** and a
10 TB/mo egress cap is a standing target. Source-level review of the NetBird relay
(`relay/cmd/root.go`, `relay/server/*`, `stun/server.go`) turned up the abuse
vectors and — crucially — that the relay has **no built-in rate/bandwidth/
connection limits**, so throttling is entirely our job. Layered defense:

**H1 — Don't run STUN at all (biggest surface cut).** NetBird's embedded STUN is a
plain, unauthenticated, un-rate-limited open responder that answers spoofed-source
binding requests — a textbook DDoS **reflector** (~2.3× amplification; scanners
enumerate open STUN within days). It is **opt-in and off by default**
(`NB_ENABLE_STUN` unset). Leave it off, and put an **external** STUN in
management's `Stuns:` block (`stun.netbird.io`, or Google/Cloudflare STUN). Peers
still get server-reflexive discovery for P2P — which actually *reduces* relay
egress vs having no STUN — while voyager exposes **zero UDP/3478**. A STUN only
echoes a caller's public IP:port back; it sees no traffic and holds no secret, so
this is the lowest-sensitivity external dependency possible and doesn't dent the
self-sovereignty goal. *(If strict sovereignty is later wanted, STUN can be
self-hosted behind the nftables rate-limits below — but default off.)* → **public
surface collapses to TCP 443 (WSS) + UDP 443 (QUIC)**, which share one port.

**H2 — Oracle security-list = exactly two rules + break-glass.** Open **only**
`443/tcp` and `443/udp` from `0.0.0.0/0` (relay must be world-reachable). The
current SL opens **SSH 22 + 2222 from `0.0.0.0/0`** — on a permanent IP that's a
scan-accreting target. **Close 22 entirely; keep 2222 world-open but hardened**
(Q8-b — DR-entry independence over scan-surface): **key-only, non-root,
fail2ban/crowdsec**, on a box that (post-Q4) no longer holds the `primary` key.
Keep the ICMP type-3 PMTU rule.

**H3 — Host nftables: default-deny + connection-rate limiting.** The relay rejects
tokenless clients cheaply at the app layer, but **only after the TLS/QUIC
handshake** — so a handshake flood burns CPU on the single core before auth. That
is the realistic self-inflicted DoS. Mitigate at the firewall:
- default-deny inbound; allow established/related, loopback, and `443/tcp+udp`;
- per-source **new-connection rate limit** on 443 via an nftables dynamic set
  (`meter`/named set with `limit rate`), plus a global SYN/UDP rate cap with burst;
- conntrack table-size cap + shorter UDP timeout (small box).
- QUIC already inherits `quic-go`'s RFC 9000 **3× anti-amplification** limit for
  free — no tuning needed, but no substitute for the rate limits.

**H4 — Everything except 443 is tailnet/loopback-only.** The relay also opens
**metrics `:9090`**, **healthcheck `:9000`**, and a `pprof` endpoint — none may
face the public IP. Bind the relay's public listener to `443` on the Oracle VNIC
address, and bind/allow metrics+health on **`tailscale0`** only (restic REST 8000
and node_exporter 9100 are already tailnet-only). Never expose pprof.

**H5 — Contain the container.** Rootless podman already (good). Add
`--read-only`, `--cap-drop=ALL`, `--security-opt=no-new-privileges`, and hard
resource caps (`--memory`, `--cpus`, `--pids-limit`) so a flood or bug can't starve
the DR-anchor's restic receiver sharing the box.

**H6 — Egress watchdog (protect the budget/cap).** The relay exposes Prometheus
metrics: **`relay_transfer_sent_bytes_total`** (egress signal), `relay_peers`,
`relay_peer_reconnections_total`. Scrape `voyager:9090` from discovery's Prometheus
**over the tailnet** and alert on `rate(relay_transfer_sent_bytes_total)` and peer
anomalies; keep the existing **$1 Oracle budget alarm** (a *notification*, not a
suspend — Q10 note). STUN being off means no UDP-3478 reflection to watch.
**Alert-only, no auto-kill (Q10, ruled):** the recoverable posture — worst case is
an email + a small charge, both recoverable — beats a self-DoS that disables the
fallback relay during the incident driving the traffic.

**H7 — Relay secret hygiene.** `NB_AUTH_SECRET` = `openssl rand -base64 32`,
identical on the relay and in management's `Relays.secret` (mismatch fails
**silently**), delivered via secrets (§9), never in git. There is **no hot-rotation
/ dual-secret overlap** — rotation = change both sides + restart (brief blip; old
24 h-TTL tokens self-expire). Document it in the key-rotation reference.

Sources: NetBird `main` source (`relay/cmd/root.go`, `relay/server/{server,handshake}.go`,
`relay/metrics/realy.go`, `stun/server.go`, `shared/relay/auth/hmac/v2`),
[environment-variables](https://docs.netbird.io/selfhosted/environment-variables),
[coturn-to-stun-migration](https://docs.netbird.io/selfhosted/migration/coturn-to-stun-migration),
[Shadowserver open-STUN report](https://www.shadowserver.org/what-we-do/network-reporting/accessible-stun-service-report/).
- **Control-plane trust — corrected during build (was over-stated).** An earlier
  draft claimed a Tailscale ACL would gate "the control plane" to admins only. The
  parallel build (WP2 SWAG-only topology + WP4's ACL analysis) proved that wrong and
  it's corrected here: **the management API and signal are *inherently* fleet-wide** —
  every peer polls management for its network map and hits signal to negotiate, so
  they *must* be reachable by all peers and cannot be ACL-restricted without breaking
  the mesh. Tailscale ACLs are also L3/L4 (`host:port`), and rule 3 already grants
  everyone `swag:443`. So the honest posture:
  - **Management API + signal** ride `swag:443` (all peers, by design). Their real
    protection is **NetBird's own authz** — OIDC/JWT, group-scoped setup keys,
    **peer approval**, and admin operations gated by an **admin JWT/PAT** — which is
    exactly what that API is built to withstand on an exposed endpoint. The residual
    "any tailnet peer can *reach* it" is acceptable: reaching ≠ authenticating.
  - **Only the human surfaces are ACL-narrowed** — the **dashboard UI** (admin) via
    a dedicated SWAG listener on **:8443**, ACL-restricted `discovery:8443 → admin
    devices` (the `tailscale/acl` rule WP4 staged). **PocketID** stays reachable by
    user-facing devices (they SSO through it), not servers. This is defence-in-depth
    on the UI, **not** the primary control — the API's authz is.

  Net: don't sell the ACL as securing the control plane; it narrows the admin UI.
  The management API is protected the way NetBird intends — by auth, peer-approval,
  and PAT scope.
- **Peer approval ON** — a new peer cannot join the network map until an admin
  approves it. Combined with scoped setup keys this closes drive-by enrollment.
- **Default-deny ACLs** — group-based policies, deny by default, managed as code
  via the Terraform provider (§8). Mirror the posture already used in the
  Tailscale `policy.hujson` (SWAG-only for non-admins, admin-only SSH, etc.).
- **Posture checks** — require a minimum NetBird/OS version (and optionally
  geo/peer-network) before a peer is trusted.
- **Relay HMAC** — `NB_AUTH_SECRET` identical on both relays and in Management's
  `relays.secret`; Management mints short-lived tokens clients present to relays.
- **Data plane** — WireGuard, end-to-end. **Relayed traffic stays E2E-encrypted;
  the relay forwards ciphertext and cannot decrypt it.** Signal is likewise
  point-to-point encrypted. So even the public voyager relay is a blind
  forwarder — it never holds plaintext or long-term secrets beyond the HMAC.
- **Secrets** — see §9. No unencrypted credential ever lands in git.

## 7. Resilience & honest failure modes

OSS NetBird gives **path-redundant relays + Postgres + client-survives-outage** —
**not** active-active control plane, and **not** "relay HA" (the grill was right to
torch that word). The honest framing:

> **The `credentialsTTL` fuse.** Relays admit peers by validating an HMAC token
> management mints with a TTL (default **24 h**). Established tunnels survive a
> management outage **indefinitely**; what expires at TTL is a peer's ability to
> *authenticate a (re)connection* to a relay. So relay redundancy is bounded by a
> clock: **the real requirement is RTO(management) < `credentialsTTL`.** Two levers
> — (1) raise `credentialsTTL` to **168 h (7 days)** to widen the survival window,
> and (2) the second OCI VM as a warm management standby to shrink RTO (§4a). With
> both, a week-long discovery outage no longer strands reconnecting peers.

Designing to exactly that:

| Failure | Effect | Mitigation in this design |
|---------|--------|---------------------------|
| One relay down (discovery **or** voyager) | Peers fail over to the other relay; direct P2P unaffected | Two relays listed in `relays[]`; clients health-check + fail over |
| **Home uplink down** | Discovery control plane + relay#1 unreachable from outside | Voyager relay + STUN keep the **data path** alive for already-authed peers; existing tunnels persist; new map updates pause until uplink returns |
| Discovery (control plane) host loss | Existing tunnels keep working; new enrol/map/reconnect blocked once past `credentialsTTL` | **Warm-standby management on the 2nd OCI VM** (§4a) with Postgres replication → promote by flipping the management DNS record; RTO ≪ 7 d TTL. Fallback if standby not built: restore Postgres from the offsite restic snapshot (RPO = last snapshot) |
| Voyager recreate | (Nothing) | **Reserved** public IP survives recreate; relay advertised by hostname anyway |
| Tailscale coordination / home DNS down | Peers can't reach the **tailnet-only** control plane (no new enrollment/map updates) | **Existing tunnels persist**; **voyager public relay keeps the data path alive** on its own public DNS name, independent of tailnet/home DNS. Admin from any tailnet-reachable device once tailnet recovers |

**Explicitly not solved (accepted):** if discovery is down you cannot enroll a
*new* peer or change policy until it's back. That's the OSS ceiling; buying it
away = Enterprise. Documented, not hidden.

## 8. IaC split (SSOT/SRP — D9)

Follows the existing "services here, policy in homelab-iac" separation.

**`desktop-nixos` (host OS + services):**

- `modules/networking/netbird-client.nix` — `flake.modules.nixos.netbird-client`,
  wraps nixpkgs `services.netbird.clients.<name>` (setup-key file + management
  URL). Opt-in per host, imported where a peer is wanted. Requires
  `services.resolved.enable` for split DNS.
- `modules/hosts/discovery/netbird-server.nix` — the control plane. **Run via
  `oci-containers` on discovery's Docker**, mirroring the proven `hermes-oci`
  declarative-container pattern (systemd-managed container, env from
  sops/vault-agent), *not* the nixpkgs `services.netbird.server` module —
  that module is **Coturn-era** and does not expose the native WS/QUIC relay
  (verify against the nixpkgs pin at build time; §11-Q2). Containers:
  `management`, `signal`, `dashboard`, `pocket-id`, `relay`.
  - **Postgres is explicit, not implicit.** NetBird management defaults to
    **SQLite**; the resilience story (offsite backup, warm standby, §4a/§7)
    *requires* PostgreSQL. Management must be configured
    (`NETBIRD_STORE_ENGINE=postgres` + DSN) against discovery's `infra` Postgres
    (or a dedicated instance, §11-Q5) — a Phase-1 checklist item, not an assumption.
  - **Mirror through Harbor + pin every image to a digest (red-team supply-chain).**
    The control plane sees every peer public key and mints tokens — a poisoned
    upstream image is game-over. Don't pull `management`/`signal`/`dashboard`/`relay`/
    `pocket-id` straight from Docker Hub/ghcr: **mirror them into the existing Harbor
    on discovery** (proxy-cache/push, already in use for kindle-dash), pin the
    **Harbor digest**, and cosign-verify where upstream signs. NetBird's topology/ports
    moved twice recently (v0.29 relay, v0.65 layout), so a floating `:latest` would
    also silently break the reverse-proxy port map — bump deliberately, re-verifying
    the port table each bump.
- `modules/services/netbird-relay.nix` — the relay as a **rootless podman**
  oci-container (`netbirdio/relay`), env `NB_AUTH_SECRET`, publishes **only :443**
  (WSS/TCP + QUIC/UDP), `NB_ENABLE_STUN` unset, metrics/health bound to
  `tailscale0` (§6b). Reused as a deferredModule for the Track-1 second relay on the
  2nd VM (§4a), which additionally runs `services.ddclient` (cloudflare) since it
  holds only an ephemeral IP.
- `modules/meta.nix` — two facts: (1) a `netbird` fact (management URL, relay
  hostnames) — `nb.<zone>` / `id.<zone>` are **internal** ingress on discovery,
  `relay.<zone>` (+ `relay2.<zone>`) are the **public** relay names; (2) a
  `fleet.overlays` fact recording both overlay CIDRs (`tailscale = 100.64.0.0/10`,
  `netbird = 10.100.0.0/16`, §4b) so no consumer ever re-collides the space. All
  read one SSOT → `fleet.json`.

**`homelab-iac` (network + policy):**

- New `netbird/` component using the **official `netbirdio/netbird` Terraform
  provider** (v0.0.9 — 0.x, treat as evolving), `management_url` pointed at the
  self-hosted API, auth via an admin PAT. Units: `groups`, `policies`
  (default-deny), `setup-keys`, `posture-checks`, `routes`/`nameservers` as
  needed. This is the NetBird analogue of the existing `tailscale/acl` unit.
  **0.x provider risk (grill #13):** pin the provider in `.terraform.lock.hcl`,
  keep state in the existing versioned+encrypted MinIO backend, gate every apply
  behind `tofu plan` review, and commit a hand-readable default-deny policy export
  so state loss can't silently open the mesh.
- `oracle/modules/instance` — (a) add a **reserved public IP**
  (`oci_core_public_ip lifetime="RESERVED"`) attached to voyager's primary private
  IP; (b) open **only `443/tcp` + `443/udp`** in the `oci_core_security_list`,
  **close public SSH 22**, keep **2222 hardened** (Q8-b; §6b-H2). Both are
  Terraform changes, as designed.
- `cloudflare/dns` — one **DNS-only** (grey-cloud) A record `relay.<zone>` →
  voyager's reserved IP. **No** tunnel hostname and **no** Access policy — the
  admin plane is tailnet-only (§5), so `nb.<zone>`/`id.<zone>` are internal
  split-DNS records (UniFi/AdGuard, from `fleet.ingress`), not Cloudflare.

Resources the TF provider exposes (confirmed): `group`, `policy`, `setup_key`,
`posture_check`, `route`, `nameserver_group`, `dns_*`, `network*`, `peer`,
`user`, `token`, `account_settings`, `identity_provider`, `scim`,
`reverse_proxy_*`.

Source: [Terraform Registry netbirdio/netbird](https://registry.terraform.io/providers/netbirdio/netbird/latest/docs).

## 9. Secrets

| Secret | Where | Delivery |
|--------|-------|----------|
| PocketID / management OIDC client secret, JWT signing | discovery | sops (`secrets/sops/secrets.yaml`, `primary`/`orion` recipients) → container env, or vault-agent (matches discovery's newer pattern) |
| `NB_AUTH_SECRET` (relay HMAC) | discovery + voyager + 2nd-VM relay | **Identical on all** (mismatch fails silently, §6b-H7). Discovery via sops. **Cloud VMs get host-specific age keys** (§11-Q4, red-team) — the NetBird secrets are encrypted to those keys, *not* delivered by the copied `primary` key, so a public-VM breach never yields `primary` |

> **Red-team note:** the public cloud VMs hold the fleet `primary` age key on disk
> today (recon). NetBird *increases* their exposure (voyager becomes a public
> relay), so §11-Q4 recommends migrating them to host-specific keys before/with this
> rollout — the primary key should not sit on an internet-facing box.
| Admin PAT (for the TF provider) | homelab-iac | `.env.sops` (dotenv), never in state — same as the Tailscale OAuth creds |
| Postgres password | discovery | reuse the `infra` stack's Postgres secret mechanism |

## 10. Phased rollout (each phase has a verify gate)

1. **Control plane up on discovery** → verify: `just dry discovery` clean;
   containers healthy; `https://nb.<zone>` dashboard loads **over the tailnet**
   from an off-LAN device (this is the empirical proof of the §5 tailnet-only /
   private-management assumption); PocketID passkey login works; `netbird status`
   from a manual test client registers.
2. **Relay #1 (discovery) + STUN wiring** → verify: test client shows a P2P (not
   relayed) connection to a second LAN client.
3. **Relay #2 (voyager)** → reserved IP pinned, Oracle SL = 443 only, nftables
   rate-limits live, relay container up (STUN off), `relay.<zone>` resolves,
   external STUN listed in mgmt `Stuns:` → verify: from an **off-LAN** client,
   `netbird status` shows the voyager relay reachable + a P2P (srflx) path via the
   external STUN; **both** `nmap -Pn -p- <ip>` (TCP) **and** `nmap -sU -p 3478,443,9090`
   (UDP — default nmap is TCP-only and would miss QUIC/3478) show **only 443** open
   publicly (no 22/3478/9090/9000); kill discovery relay, confirm failover.
4. **IaC policy** in homelab-iac: groups + default-deny + setup-keys + posture →
   verify: `tofu plan` no-op after apply; an un-approved peer is blocked; an
   out-of-posture peer is denied.
5. **Client module** rolled to the first real fleet peers (opt-in) → verify:
   coexists with tailscale0 (both interfaces up); **`ip route get 10.100.0.1` and
   `ip route get 100.64.0.1` on a dual-homed host resolve to `wt0` and
   `tailscale0` respectively — no ambiguity** (§4b); split-DNS resolves both
   `*.netbird.internal` and `*.ts.net`; `just dry <host>` + post-switch
   `systemctl status netbird-*`.
6. **Second VM — Track 1 (§4a):** 2nd AMD micro in a different Fault Domain →
   relay#3 (ephemeral IP via ddclient) + Postgres **read-replica** streaming from
   discovery → verify: `relay2.<zone>` reachable + failover; replica lag ~0;
   `nmap` surface = 443 only (as phase 3).
7. **DR drill**: kill discovery management; confirm existing tunnels persist and a
   peer past `credentialsTTL` is (as expected) blocked; then **promote the replica +
   start standby management + flip `nb.<zone>` DNS** and confirm the network map
   returns and a new peer can enrol — the RTO<TTL proof (§7).

## 11. Decisions (ruled 2026-07-10)

All gates are ruled; the RFC below reflects them. Kept as a record of *what* and
*why*.

| # | Decision | Ruling |
|---|----------|--------|
| Q1 | Container runtime, discovery control plane | **Docker oci-containers** (match discovery's rootful Docker; rootless-podman was abandoned there over a btrfs exec-bit bug). |
| Q2 | nixpkgs module vs oci-containers | **oci-containers** — the native WS/QUIC relay + PocketID + combined server aren't in the Coturn-era `services.netbird.server`. Client peers still use the nixpkgs `services.netbird.clients.*` module. |
| Q3 | Voyager/relay TLS | **NetBird relay built-in Let's Encrypt** (`NB_LETSENCRYPT_*`) — fewest moving parts on the offsite host. |
| Q4 | Cloud-VM secret delivery | **Host-specific age keys** for voyager + the 2nd VM — the `primary` fleet key must not sit on an internet-facing box. Spawns a **follow-up study** (§14). |
| Q5 | Postgres | **Reuse discovery's `infra` Postgres** (one less service). |
| Q6 | PocketID login-code | **Keep** the one-time login-code recovery path — accepted as a deliberate out-of-band admin recovery (avoids the single-admin self-brick the grill flagged). |
| Q7 | Tailnet-only management | **Keep for now** — accept the bootstrap coupling (join Tailscale first). Revisited only by the §13 transition plan. |
| Q8 | Break-glass SSH on voyager | **(b) Keep 2222 world-open, hardened** — key-only, non-root, fail2ban/crowdsec (§6b-H2). DR-entry independence wins over scan-surface. Public SSH **22** still closed. |
| Q9 | STUN | **External** (`stun.netbird.io` + Google/Cloudflare as fallbacks) — lowest-sensitivity dependency, lowers relay egress, zero self-hosted reflector. |
| Q10 | Egress hard-stop | **Alert-only, recoverable** — no auto-kill. See the billing note below: the Oracle *budget* is a **notification, not a suspend**, and 10 TB/mo egress is free, so the cost risk is mild and non-catastrophic; keeping the relay up (a recoverable, manually-handled posture) beats a self-DoS auto-kill, even if it caps cost less strictly. |
| Q11 | Second-VM role | **Track 1 now** (2nd AMD micro = relay#3 + Postgres read-replica); **Track 2 tracked follow-up** (A1/telstar warm-standby management) when A1 capacity frees, pending the telstar threat-model call. |

> **Q10 — "billing where?"** The charge source is **egress beyond the Always-Free
> 10 TB/mo** (a fallback relay won't approach it) or the unconfirmed reserved-IP
> edge case (§4). The **$1 Oracle budget alarm is a *budget notification*, not a
> kill-switch** — a budget by itself never terminates resources; Always-Free
> suspension happens only on real accrued charges with no payment path. So "recoverable
> option" = alert-only: worst case is an email + a small charge, both recoverable,
> vs auto-kill which self-disables the fallback path during the very incident driving
> traffic. Chosen accordingly.

## 12. Footprint & cost

- **Discovery:** management + signal + dashboard + PocketID + relay ≈ light Go/JS
  services; PocketID is far lighter than Zitadel (no CockroachDB). Postgres
  reused. Fits alongside the existing stacks.
- **Voyager:** relay only — tens of MB RAM, ~16 MB image, capped by cgroups
  (§6b-H5). Well within 1 GB. The reserved public IP is **free** (1 included in
  Always-Free). External STUN means peers keep doing P2P, so relay egress stays a
  fallback trickle — but it counts against Oracle's (generous, 10 TB/mo) allowance
  and the **$1 budget alarm**, watched via `relay_transfer_sent_bytes_total`
  (§6b-H6). If peers routinely relay bulk traffic through voyager, revisit sizing.
- **Second VM (§4a):** free within Always-Free (2nd AMD micro uses the other free
  micro slot; ephemeral IP + ddclient). A1/telstar standby stays inside the (now
  2 OCPU / 12 GB) A1 pool. No Enterprise licence anywhere.
- **No new SaaS**, no Tailscale changes, and the **only new public surface is port
  443 on the relay VM(s)** (DNS-only Cloudflare records → their IPs).

## 13. Transition study (Tailscale ↔ NetBird)

L1 keeps **both** overlays running now. This section is the *study*, not a
committed migration — the decision is made later, on evidence.

**Why not decide now:** Tailscale is load-bearing (discovery subnet-router,
MagicDNS split-DNS, ACLs-as-code, and — critically — NetBird's own bootstrap path
depends on it, §5). Cutting over before NetBird has proven itself would remove the
net under NetBird.

**What coexistence must prove before a transition is even considered:**

- NetBird control plane survives a real discovery outage within `credentialsTTL`
  (§7), *with* the §4a standby — i.e. NetBird's resilience ≥ Tailscale's.
- Split-DNS + addressing (§4b) run collision-free for weeks with no route/DNS
  incidents on dual-homed hosts.
- Every capability Tailscale currently provides has a proven NetBird equivalent:
  subnet routing (discovery `.210/.1/.2` routes → NetBird `network_router`/`route`),
  MagicDNS (→ NetBird DNS + nameserver groups), exit-node needs (if any), and the
  `homelab-iac` ACL policy (→ `netbird/policies`).
- The bootstrap-coupling is broken in the right order: NetBird can only replace
  Tailscale once NetBird no longer *needs* Tailscale to enrol a fresh peer — i.e.
  management must become reachable by a not-yet-on-any-overlay device (which means
  re-introducing a controlled public management endpoint, reversing §5's tailnet-
  only simplification). **This is the crux of any transition** and the main reason
  it's deferred.

**Transition sequence (if/when triggered):** (1) reach NetBird capability parity
above; (2) stand up a controlled public management endpoint (CF Tunnel, NetBird-
auth only) so NetBird self-bootstraps; (3) migrate subnet routes + DNS to NetBird,
run duplicated for a soak period; (4) move ACL SSOT from `tailscale/acl` to
`netbird/policies`; (5) drain Tailscale (remove `--accept-routes` reliance), retire
the `tailscale` module + `tailscale/` IaC last. **No step removes Tailscale until
its replacement is proven live.** Each is independently reversible.

**Explicitly out of scope now:** any change to the `tailscale.nix` module,
`tailscale/acl`, or the discovery subnet-router. This RFC only *adds* NetBird.

## 14. Spawned follow-up — fleet & environment security-hardening study

Q4 surfaced a pre-existing exposure bigger than NetBird itself: the **`primary`
fleet age key is copied onto public cloud VMs** (voyager, and telstar-to-be), so any
public-VM compromise yields the key that decrypts *all* fleet secrets. NetBird only
sharpens it (voyager becomes a public relay). Fixing it host-locally (host-specific
keys) is in-scope here; the broader pattern deserves its **own RFC**, proposed as
future work:

**Proposed study — "Fleet secret blast-radius & public-surface hardening"** (own
`docs/proposals/` doc, human-authored). Scope to investigate:

- **age-key topology / blast radius** — per-host keys vs the shared `primary`; which
  hosts should be able to decrypt what; retire `primary`-on-public-VM everywhere
  (not just for NetBird); reconcile with the existing `reference/key-rotation.md`.
- **Public-surface inventory & threat model** — every internet-reachable port across
  voyager/telstar/Cloudflare-tunnel/SWAG; a standing "what can the internet touch"
  audit (extend `reference/service-exposure.md` beyond discovery).
- **Tailnet trust flattening** — the R1 finding generalizes: "on the tailnet" is
  treated as trusted fleet-wide; audit which services assume it and gate the
  sensitive ones (NetBird control plane, OpenBao, Harbor, admin SSH) with explicit
  ACLs.
- **Secret-at-rest on cloud hosts** — sops delivery vs Vault-agent vs host-key;
  crown-jewel isolation (the offsite DR anchor sharing a box with a public relay).
- **Supply chain** — mirror-through-Harbor + cosign as a fleet default for
  externally-sourced container images, not per-service ad hoc.

This RFC implements the **NetBird-local** slice (host-specific keys, control-plane
ACL, Harbor mirror); the study takes the **fleet-wide** version.

---

*Cross-refs:* [`implemented/2026-06-30-offsite-dr-crown-jewels.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-30-offsite-dr-crown-jewels.md)
(voyager DR anchor), [`implemented/2026-06-29-repo-ssot-srp.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-repo-ssot-srp.md)
(D9 model), [`reference/service-exposure.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/service-exposure.md)
(exposure audit method).
