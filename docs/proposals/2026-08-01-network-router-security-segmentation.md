# Home network and router security segmentation

**Status:** Proposed — live sweep and detection-control review complete;
containment and authenticated controller inventory not started
**Date:** 2026-08-01
**Last reviewed:** 2026-08-03
**Owners:** `homelab-iac` (UniFi networks, WLANs, edge policy),
`desktop-nixos` (host firewall, service authorization, and managed-host
inventory), `servarr` (Wazuh rules and event delivery), and `homelab`
(cross-repo evidence and rollout gates)

## Goal

Contain an untrusted household device without losing Internet, Home Assistant,
Protect, printing, storage, or administrative access. Preserve the existing
server addresses and use the smallest policy set that closes the verified
lateral-movement paths.

This proposal does not authorize a UniFi apply. Network changes must run from
a wired host with a tested rollback path, per `homelab-iac` policy.

## Sweep scope and limitations

Point-in-time evidence was collected on 2026-08-01 from Endeavour on Main
(`192.168.10.0/24`). Checks were non-destructive: ARP/ICMP discovery, TCP
connect/SYN scans, selected UDP probes, safe Nmap scripts, HTTP status checks,
TLS enumeration, DNS queries, configuration review, and external self-scans.
No password guessing, exploit scripts, packet floods, service mutation, or
router apply ran.

- Main: 33 responsive addresses. Some are duplicate logical endpoints on one
  physical MAC, so this is not a count of 33 physical devices.
- Default: gateway `192.168.1.1` plus an unidentified `192.168.1.2` reachable
  from Main.
- Authenticated UniFi inventory was not run. The only local API-key-shaped file
  is not a sanctioned `*.secrets.json` handoff and has mode `0644`; it was not
  read. Firmware compliance, UI accounts/MFA, current zone policy, configured
  port forwards, and IDS/IPS state therefore remain unverified.
- External TCP: the home WAN IPv4 exposed none of 68 relevant ports; a full
  65,535-port run found no open port before the edge's silent drops hit the
  five-minute host timeout. Full external IPv6 self-scans found zero open TCP
  ports on Endeavour, Discovery, Kepler, and Orion. Archinaut reached 84% with
  zero open ports before the scanner stalled. External UDP remained
  inconclusive because silence is reported as `open|filtered`.
- Sleeping/offline devices remain a blind spot. NanoKVM and Pathfinder were
  offline during the sweep.
- A read-only follow-up on 2026-08-03 found only Wazuh's local manager agent
  registered. Its checked configuration runs Syscollector hourly with port
  and process collection, and its UniFi rule already classifies `honeypot`
  events as warnings. No OpenCanary, Cowrie, standalone network IDS, or
  scheduled agentless port-drift scanner exists in the component repositories.
  Native UniFi honeypot and IDS/IPS enablement remain unverified until the
  authenticated controller inventory.

## Executive findings

| Priority | Finding | Evidence | Required disposition |
|---|---|---|---|
| P0 | Untrusted devices and privileged servers share Main | TVs, streaming devices, Amazon devices, phones, Roborock, cameras, APs, HAOS, NAS, workstations, and servers all answered on `192.168.10.0/24` | Split clients, IoT, and cameras from Main; default-deny inter-zone for IPv4 and IPv6 |
| P0 | Kepler trusts the whole flat LAN as root-capable NFS clients | `/fast` is exported `rw,no_root_squash` to `192.168.10.0/24`; TCP 111/2049/4000-4002 is reachable across Main | Narrow exports and host firewall to named clients before VLAN migration; retain `no_root_squash` only for the isolated k3s subnet that requires it |
| P0 | Printer control is unauthenticated from the whole flat LAN | Archinaut exposes 80/7125/8080; `/server/info`, `/access/info`, and `/printer/info` return HTTP 200. Moonraker trusts `192.168.0.0/16` and has `allowSystemControl = true` | Put Archinaut behind a source allow-list before moving it to IoT; only admin/HA paths may reach 80/7125/8080 |
| P1 | Gateway and network-device management are LAN-wide | UDM answers on 39 TCP ports; AP/bridge SSH is reachable; both swOS switches expose plaintext HTTP | Restrict Gateway/management access to Tailscale-subnet-router SNAT plus one wired break-glass host; move ordinary WiFi clients off Main |
| P1 | Five Protect cameras are directly manageable from Main | Each camera exposes HTTP/HTTPS; the UDM exposes Protect's 7441-7447, 7451, 7550, 7552, and 7888 surfaces | Move cameras/Protect bridge to a camera VLAN; allow only controller/Protect flows and deny camera-to-LAN/client traffic |
| P1 | `192.168.1.2` crosses the Default/Main boundary with legacy management | TCP 22, 23, 80, and 2222 accept connections; the device does not answer ICMP or complete safe banner probes | Identify and patch/remove it before repurposing Default. Telnet must not remain reachable from Main |
| P1 | UniFi automation does not authenticate the controller certificate | Controller certificate is self-signed, lacks the management IP SAN, expires 2026-08-16, and `allow_insecure = true` | Install/renew a trusted controller certificate and switch IaC to a matching DNS name with verification enabled |
| P1 | A Ubiquiti bridge reports unmanaged/default state | `.69`, named `U6Pro`, identifies as `UFP-UAP-B` / `Unifi-Protect-UAP-Bridge`, firmware `v1.1.0`, `config_status: default/unmanaged`; SSH accepts password authentication | Reconcile identity/adoption in the controller; rotate device credentials and isolate before trusting it |
| P1 | Tailscale admin identity is stale in code | live/offline Pathfinder is `100.102.248.13`; `policy.hujson` names `100.104.92.5`, which has no matching peer | Update the named host and policy tests before any network rollout |
| P1 | Managed-host port inventory is not fleet-wide | Wazuh Syscollector is configured hourly, but live `agent_control` lists only local agent `000`; the other hosts therefore have no central listener inventory | Reuse the planned Wazuh agent rollout and collect listening ports/processes; alert only on a new or widened listener outside the host's declared exposure |
| P1 | Switch access/trunk policy is absent from IaC | `homelab-iac` declares networks and WLANs but no switch-port profiles; an unknown wired device can still land on Main | Inventory every switch port, disable unused ports, pin access ports to one zone, restrict trunks to named VLANs, and alert on protected-port/client changes where UniFi emits them |
| P2 | Honeypot detection is wired but no decoy is proven | UniFi CEF reaches Wazuh and rule `100101` matches `honeypot`, but no repository or authenticated inventory proves a honeypot address exists | Use the gateway's native per-network honeypot and prove one synthetic hit reaches Wazuh; do not add a honeypot workload yet |
| P2 | Two WLANs explicitly disable PMF | `Que Wifi?` and `Wifi Errado` use WPA2 with `pmf_mode = "disabled"`; `Fast` correctly uses WPA3 with PMF required | Use WPA2/WPA3 transition + PMF optional for normal clients; keep PMF disabled only on a separate legacy-IoT SSID with proven incompatible clients |
| P2 | SMB signing is optional | Kepler and its `.245`/`.250` endpoints report SMB 3.1.1 signing enabled but not required | Require signing after checking client compatibility; keep network source restrictions regardless |
| P2 | IaC/live WLAN mapping needs reconciliation | HCL comments say all SSIDs use Default, while the active `Wifi Errado` DHCP lease is on Main | Run authenticated refresh/plan from wired LAN and correct comments/IDs before changing WLAN mappings |
| P2 | Local API-key file permissions are too broad | ignored `homelab-iac/unifi-api-key.json` is mode `0644` | Replace it with a purpose-named root `*.secrets.json` handoff at `0600`, rotate if other local users could read it, consume, then delete it |

## Positive controls verified

- UPnP/SSDP on the UDM is closed from Main; keep it disabled.
- No UniFi port-forward is declared, and the external TCP probes found no home
  WAN listener.
- UDM HTTPS supports TLS 1.2/1.3 with strong cipher suites. HTTP redirects to
  HTTPS and the UI emits HSTS and defensive browser headers.
- UDM debug mode is off.
- Public `ha` and `whisper` routes are Cloudflare-tunnelled and return a
  Cloudflare Access challenge when resolved through public DNS.
- DNS on the UDM, Discovery, and Kepler resolves successfully from Main.
- Fleet OpenSSH uses public-key authentication on port 2222. HAOS also offered
  public-key-only SSH in the probe.

## Observed device inventory

`none` means no port from the bounded common/service set answered; it does not
prove that every TCP/UDP port is closed.

| Address | Observed identity | Class | Reachable TCP surface | Target placement |
|---|---|---|---|---|
| `.1` | UDM Pro | Gateway/Protect | DNS, web/UI/API, UniFi/Protect internal ports (39 total) | Gateway zone; management allow-list |
| `.2`, `.3` | MikroTik RouterBOARD/SwOS | Switch management | 80/plain HTTP | Main management initially; dedicated management VLAN later only if swOS rollback is proven |
| `.20`, `.91`, `.98`, `.130`, `.189`, `.198` | Amazon devices | IoT | none | IoT |
| `.35` | Roborock vacuum | IoT | none | IoT |
| `.68`, `.83`, `.188` | Samsung phones/private MACs | Clients | none | Clients |
| `.69` | UFP-UAP-B Protect WiFi bridge, misleading hostname `U6Pro` | Camera infrastructure | 22, 8080; UDP discovery reports default/unmanaged | Cameras; reconcile adoption first |
| `.73`, `.150`, `.159`, `.160`, `.164` | UniFi Protect cameras (`.159` names itself `g5-flex`) | Cameras | 80, 443 | Cameras |
| `.107`, `.161` | U7 Pro APs | Network infrastructure | 22, 8901 | Main management initially |
| `.112`, `.158` | one LG webOS TV MAC with two observed addresses | IoT | none | IoT; clear stale lease/address |
| `.115` | HAOS VM | Automation server | 22, 111, 1883, 8123, 8883 | Main/Servers |
| `.147` | Laptop | Client/admin | 2222, 22000 | Clients; administer through Tailscale |
| `.148` | Samsung device | IoT | 8080 | IoT |
| `.178` | Nvidia Android device | IoT | ADB 5555 (token auth), 8008, 8009, 8443, 9000, 10001 | IoT; disable network ADB if unused |
| `.205` | Endeavour | Wired/WiFi admin | 111, 2222, 22000 | Clients on WiFi; one wired break-glass reservation may stay on Main |
| `.210` | Discovery | Server/ingress/DNS | 53, 80, 443, 2222, 8091, 9000, 9001, 22000, 32400 | Main/Servers |
| `.220` | Orion | Server | 2222, 5000, 8080, 22000 | Main/Servers |
| `.225` | Archinaut/Klipper | Physical-control IoT | 80, 2222, 7125, 8080 | IoT after host allow-list; admin through Tailscale |
| `.230`, `.245`, `.250` | Kepler plus Kepler-owned endpoints sharing one MAC | Server/storage/cluster | DNS, NFS/RPC, SMB, SSH, API, Syncthing | Main/Servers |
| `192.168.1.2` | Unknown; routed through UDM | Unknown management device | 22, 23, 80, 2222; banner probes time out | Quarantine/identify before any Default change |
| `.4` | NanoKVM | Administrative appliance | offline during sweep | Main management; Tailscale-admin only |
| `.215` | Pathfinder | Admin workstation | offline during sweep | Clients; fix tailnet identity first |

## Target network layout

Preserve Main and server IPs. Add only the segments required by observed trust
boundaries.

| Network | Suggested VLAN/CIDR | Members | Base posture |
|---|---|---|---|
| Main / Servers | existing VLAN 2, `192.168.10.0/24` | UDM-adjacent management, servers, HAOS, one wired break-glass admin | No ordinary WiFi/IoT; same-VLAN server flows remain unchanged |
| Clients | VLAN 20, `192.168.20.0/24` | laptops, phones, trusted interactive clients | Internet; explicit ingress/storage/sync paths; no Gateway management |
| IoT | VLAN 30, `192.168.30.0/24` | Amazon, Roborock, TVs, Nvidia, Archinaut | Isolated, Internet + gateway DNS/NTP; explicit HA/admin exceptions only |
| Cameras | VLAN 40, `192.168.40.0/24` | Protect cameras and UFP bridge | Isolated; Protect/controller ports only; no general client/server reach |
| Default | existing `192.168.1.0/24` | unknown until `.1.2` is identified | Freeze; do not reuse or extend |

WLAN reuse avoids another SSID:

- `Fast` -> Clients, WPA3, PMF required.
- `Wifi Errado` -> Clients, WPA2/WPA3 transition, PMF optional.
- `Que Wifi?` -> IoT, WPA2, PMF optional. Use disabled only for a named device
  that demonstrably cannot associate.

Enable WLAN L2 isolation on IoT. It protects WiFi peers but does not replace
VLAN policy for wired devices or traffic crossing non-UniFi swOS switches.

### IoT admission and egress policy

- Give every infrastructure, IoT, camera, and physical-control device an owner,
  class, and stable reservation before migration. A new or unknown device does
  not join Main: block it pending ownership, then use an Internet-only
  quarantine network after Default is cleared. Randomized phone MACs remain a
  Clients-inventory concern, not automatic IoT admission.
- Pin wired IoT/camera access ports to one VLAN. Only AP, controller, and
  intentional hypervisor/uplink ports are trunks, with an explicit VLAN
  allow-list. Disable unused switch ports. Do not leave Main as the effective
  native network on user-access wall ports.
- Supply gateway DNS and NTP through DHCP. Allow IoT DNS only to the named
  resolver on TCP/UDP 53 and NTP only to the named source on UDP 123; deny
  direct external DNS and DoT (`853/tcp`). DoH blocking remains deferred
  because maintaining endpoint lists is not justified.
- Start ordinary IoT with Internet egress, but deny routed private/ULA zones,
  outbound SMTP (`25/tcp`), SMB (`445/tcp`), and NFS/RPC
  (`111`, `2049`, `4000-4002` TCP/UDP). Record flows for a canary before any
  per-vendor Internet allow-list. Cameras stay Internet-denied except a bounded
  firmware-update window proven necessary by a canary.
- Prefer HAOS-initiated sessions into IoT. Permit an IoT-initiated callback
  only for a named integration and port. Keep cross-network mDNS off until a
  canary fails; then reflect only between the required networks and service
  types supported by the controller.
- Apply the same routed policy to IPv4 and IPv6. WLAN client isolation is an
  additional L2 control, not the IPv6 policy.

## Required policy matrix

Policies are stateful. Specific allows precede the broad deny. Apply the same
intent to IPv4 and IPv6; an IPv4-only rule set is a failed rollout.

| Source | Destination | Allow | Deny/default |
|---|---|---|---|
| External | all home zones/Gateway | established/related only; Cloudflare/Tailscale outbound tunnels | all unsolicited IPv4 and IPv6; no port forwards |
| Clients | External | normal outbound | inbound by default |
| Clients | Main | Discovery DNS 53 TCP/UDP and ingress 80/443; Kepler storage ports for named clients; Syncthing 22000; any additional port only with a named consumer | all other Main and Gateway management |
| Main | Clients | established/related; named Syncthing peers if bidirectional initiation is required | all other new connections |
| IoT | Gateway | DHCP, DNS, NTP | Gateway UI/API/SSH and all other services |
| IoT | External | initially normal outbound; measure before narrowing | unsolicited inbound |
| IoT | Main/Clients/Cameras | only device-specific callbacks proven by Home Assistant | all other traffic |
| HAOS `.115` | IoT | device-control ports documented per integration; start with HAOS-to-IoT during migration, then narrow | no access to Cameras/management unless explicitly required |
| Clients/admin | IoT | no broad path; use Tailscale-admin route for maintenance. Allow Archinaut 80/7125/8080 only from named admin sources if a direct LAN path is required | all other client-to-IoT |
| Cameras | Gateway/Protect | controller/Protect ports from Ubiquiti's required-port list: 7441-7447, 7451, 7550, 7552, 7888, plus DHCP/DNS/NTP | all other Gateway services |
| Gateway/Protect | Cameras | corresponding established/controller flows | no camera VLAN transit to other zones |
| Cameras | External/Main/Clients/IoT | firmware/update egress only if a canary proves it is required | default deny |
| Tailscale subnet router `.210` and wired Endeavour | Gateway/network devices | management ports required by UDM, swOS, NanoKVM, APs | every other source denied |

Keep UPnP disabled. Keep `relay.pastelariadev.com` on the non-routable
placeholder until Voyager's reserved address exists. Public Home Assistant and
Whisper remain behind Cloudflare Access; do not add home-router forwards.

## Monitoring and deception policy

Reuse the deployed controls. The runtime-security proposal already owns
firewall-reject scan detection, persistent unknown-client detection, public
edge drift, and the Suricata/Zeek decision gate. This proposal adds only the
missing network exposure checks. None of them may delay the P0 NFS/Moonraker
containment or the first VLAN canary.

| Surface | Minimum control | Owner and action |
|---|---|---|
| Managed-host listeners | Wazuh Syscollector hourly, restricted to listening ports for fleet agents; compare protocol, bind address, port, and process with the host's declared exposure | `desktop-nixos` renders the agent policy; `servarr` warns on a new wildcard/untrusted-interface listener. A removed listener stays an availability event, not a security page |
| Agentless gateway, switch, camera, and IoT surfaces | One bounded observe-only scan from a named monitoring source after controller/policy changes and weekly during migration; scan the documented management/service set, not continuous full-port sweeps | `desktop-nixos` owns the probe runtime; `homelab-iac` owns target zones and expected reachability. Review and accept a baseline before alerting on additions |
| WAN exposure | Declarative drift asserts no port forward and UPnP disabled; repeat the external IPv4 and global-IPv6 scan after gateway, ISP, or host-firewall changes | `homelab-iac`; any new listener or widened source CIDR is critical |
| Physical switch ports | Fixed access/trunk profiles, unused ports disabled, and protected-zone client/configuration events retained through UniFi CEF where available | `homelab-iac`; a new client on Main/management or an unplanned port-profile change is critical |
| Lateral scanning | Rate-limited firewall rejects plus the native UniFi honeypot; scheduled scanner source is named and time-bounded | `servarr` correlates source, zone, distinct ports, and honeypot hit without Prometheus IP/port labels |

### Honeypot decision

Use UniFi Gateway Honeypot first. It is already on the UDM, uses an unused IP
on a selected network, creates a Security Detection on contact, and can reuse
the live CEF-to-Wazuh path. Reserve a controller-confirmed address outside the
DHCP pool on Main during migration, then on Clients and IoT. Add Cameras only
after its canary is stable. Never port-forward a decoy.

Test with one controlled connection to the documented honeypot test port.
Confirm source IP/MAC, network, destination, and time survive CEF decoding and
rule `100101`; then replace the generic keyword rule with a honeypot-specific
signature. A hit from the named scanner during its maintenance window is test
evidence. Any other hit requires identifying the client and checking its
processes, DNS, recent configuration, and peer traffic; do not auto-isolate.

OpenCanary is the fallback only if the native event lacks the source/protocol
detail needed for an investigation. Cowrie is not justified: its interactive
SSH/Telnet emulation, captured commands, and uploaded files create a malware,
privacy, egress, and maintenance boundary this defensive sweep does not need.
If a fallback is later approved, it must be low-interaction, isolated from all
trusted zones, denied egress except DNS/NTP/log delivery, contain no production
credentials or mounts, and remain LAN-only.

## `homelab-iac` implementation

### 1. Reconcile before changing anything

1. Accept a minimal root `unifi-audit.secrets.json` handoff at mode `0600`.
   Consume only the API-key field, export a redacted controller inventory, then
   delete the handoff.
2. Run a wired `terragrunt plan`/refresh for network, WLAN, reservations, DNS,
   and any live policy resources. Resolve the HCL/live WLAN-network mismatch.
3. Identify `192.168.1.2`, reconcile `.69` adoption/firmware, and list every
   current port forward, UPnP setting, firewall zone/policy, IDS/IPS setting,
   honeypot network/address, switch-port profile, unused port, CEF category,
   admin account/MFA state, device firmware, and remote-access owner.
4. Fix Pathfinder's named Tailscale address and tests independently. Do not
   couple that low-risk correction to a router apply.

### 2. Close host-level P0 paths first

In `desktop-nixos`, before moving a client:

- replace Kepler's `/24` and whole-tailnet NFS trust with named source CIDRs;
- remove `no_root_squash` from human/client exports; keep it only for
  `10.250.0.0/24` k3s storage where required;
- source-scope NFS/RPC/SMB/model APIs in the host firewall;
- make SMB signing mandatory after a client canary;
- replace Moonraker's `192.168.0.0/16` trust with named admin/HA sources and
  source-scope ports 80/7125/8080;
- disable Nvidia network ADB if it is not deliberately used.

This makes the dangerous services safe before routing changes can create a
false sense of isolation.

### 3. Add managed networks and WLAN settings

Use the existing `unifi/modules/network` and `unifi/modules/wlan`; do not add a
new provider or abstraction.

- expose the provider's existing `network_isolation_enabled` field and use it
  for IoT/Cameras;
- expose WLAN `l2_isolation` and use it for the IoT SSID;
- add Clients/IoT/Cameras network entries and DHCP pools;
- map existing SSIDs as above;
- preserve `Fast` WPA3 + required PMF; change the other two only as specified;
- set DHCP DNS/NTP intentionally per zone instead of enabling broad cross-zone
  access;
- stop globally enabling multicast DNS. Add only the required service
  discoveries between Clients and IoT after a failed functional test names
  them.

The pinned `filipowm/unifi` provider does not support current UniFi zone-based
firewall policies. Use native UniFi ZBF for the matrix above. Record the exact
manual rules, switch-port profiles, IDS/IPS mode, honeypot networks/addresses,
CEF settings, and disabled ports in
`homelab-iac/unifi/environments/home/POLICY.md`; do not build a custom
Terraform provider. Add read-only drift comparison only if the official API
can export these objects reliably without secrets.

Start IDS in notify-only mode on the routed Main, Clients, IoT, and Cameras
networks. Run the official synthetic test, retain seven days of detections, and
review false positives and gateway load. Promote reviewed signatures to
notify-and-block only when each alert has an operator action; do not add
Suricata or Zeek beside the gateway without a proven visibility gap.

### 4. Roll out one canary at a time

1. Create VLANs/policies with no clients attached.
2. Move one low-impact Amazon/Roborock device to IoT. Prove Internet, DHCP,
   DNS, HA control, and denial to Main/Gateway management.
3. Move `.69` only after adoption is reconciled, then one camera. Prove live
   view, recording, events, reboot, and denial to Main/Clients.
4. Move Archinaut. Prove Mainsail, Moonraker, webcam, HA power control, print
   start/cancel, reboot, and denial from an ordinary IoT client.
5. Move `Fast`, then `Wifi Errado`, to Clients. Keep wired Endeavour as the
   rollback path throughout.
6. Move remaining devices in bounded groups. Do not repurpose Default until
   `.1.2` is owned or removed.

## Acceptance gates

- Fresh authenticated UniFi inventory has no unknown port forward, UPnP is
  disabled, IDS/IPS and honeypot state are recorded, switch access/trunk
  profiles are reviewed, unused ports are disabled, and every administrator
  has MFA.
- From IoT and Cameras, TCP 22/80/111/443/445/2049/2222/4000-4002/7125/8080
  to Main fails except the named matrix allows.
- From Clients, UDM management and swOS HTTP fail; Discovery ingress/DNS and
  named storage/sync paths work.
- From a non-approved Main/Client address, NFS export discovery/mount and
  Moonraker access fail even if the gateway rule is accidentally relaxed.
- IPv4 and IPv6 tests produce the same allow/deny result.
- Protect live view, continuous recording, motion events, firmware update,
  camera reboot, and console reboot pass for the canary.
- External self-scans again report no unexpected TCP port for WAN IPv4 and each
  global-IPv6 host class.
- One controlled honeypot connection produces one UniFi Security Detection and
  one source-attributed Wazuh event; an ordinary IoT client cannot reach the
  honeypot on another zone.
- Wazuh lists every enrolled canary's listening ports and owning processes. A
  synthetic unexpected wildcard listener warns; stopping an expected service
  remains owned by service-health monitoring.
- The named agentless probe sees only the policy matrix's allowed management
  and service ports. Its scheduled scan does not create an operator page.
- A new client on Main/management and an unplanned UniFi port-profile or
  firewall-policy change produce retained, source-attributed evidence.
- A saved, reviewed plan contains only the intended network/WLAN changes. Apply
  from wired LAN; verify after each canary; retain the previous UniFi backup.

## Rollback

- Keep original SSID-to-network mappings and DHCP leases documented.
- Revert only the last canary's port/SSID mapping, not the whole policy set.
- Keep wired Endeavour on Main until every client/camera/IoT gate passes.
- Restore the pre-change UniFi backup only for controller-wide failure; normal
  rollback is the last mapping/policy reversal.
- Do not delete old networks until at least one full DHCP lease period and a
  controller reboot have passed cleanly.

## Deferred by design

- Dedicated management VLAN: move APs/swOS/NanoKVM later only if Main no longer
  gives sufficient isolation and swOS VLAN rollback is proven.
- Per-device Internet allow-lists, DNS-over-HTTPS blocking, country blocking,
  and learned anomaly detection: add only after retained flow evidence names a
  failure the base segmentation does not cover.
- OpenCanary, Cowrie, T-Pot, Internet-facing honeypots, and malware collection:
  the native gateway honeypot covers the current lateral-scan question without
  adding an exposed workload.
- Continuous full-port scanning and a new SNMP/exporter stack: use Wazuh
  listener inventory, bounded agentless scans, UniFi CEF, and post-change
  external verification first.
- Suricata/Zeek: retain the existing runtime-security decision gate; add only
  if gateway/firewall/DNS evidence cannot answer a documented incident.
- A custom Terraform provider for UniFi ZBF: do not own this maintenance burden.

## Sources

- [UniFi zone-based firewalls](https://help.ui.com/hc/en-us/articles/115003173168-Zone-Based-Firewalls-in-UniFi)
- [UniFi network and client isolation](https://help.ui.com/hc/en-us/articles/18965560820247-Implementing-Network-and-Client-Isolation-in-UniFi)
- [UniFi required ports](https://help.ui.com/hc/en-us/articles/218506997-Required-Ports-Reference)
- [UniFi WLAN security and PMF](https://help.ui.com/hc/en-us/articles/32065480092951-UniFi-WiFi-SSID-and-AP-Settings-Overview)
- [UniFi UPnP guidance](https://help.ui.com/hc/en-us/articles/12648697125783-UniFi-Gateway-UPnP)
- [UniFi Gateway Honeypot](https://help.ui.com/hc/en-us/articles/12569193992727-UniFi-Gateway-Honeypot)
- [UniFi IDS/IPS](https://help.ui.com/hc/en-us/articles/360006893234-UniFi-Gateway-Intrusion-Detection-and-Prevention-IDS-IPS)
- [Wazuh system inventory configuration](https://documentation.wazuh.com/current/user-manual/capabilities/system-inventory/configuration.html)
- [OpenCanary](https://github.com/thinkst/opencanary)
- [Cowrie](https://docs.cowrie.org/en/stable/README.html)
- [filipowm/unifi provider](https://github.com/filipowm/terraform-provider-unifi)
