# Home network and router security segmentation

**Status:** Proposed — live sweep complete; containment and authenticated
controller inventory not started
**Date:** 2026-08-01
**Owners:** `homelab-iac` (UniFi networks, WLANs, edge policy),
`desktop-nixos` (host firewall and service authorization), and `homelab`
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

## `homelab-iac` implementation

### 1. Reconcile before changing anything

1. Accept a minimal root `unifi-audit.secrets.json` handoff at mode `0600`.
   Consume only the API-key field, export a redacted controller inventory, then
   delete the handoff.
2. Run a wired `terragrunt plan`/refresh for network, WLAN, reservations, DNS,
   and any live policy resources. Resolve the HCL/live WLAN-network mismatch.
3. Identify `192.168.1.2`, reconcile `.69` adoption/firmware, and list every
   current port forward, UPnP setting, firewall zone/policy, IDS/IPS setting,
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
manual rules in `homelab-iac/unifi/environments/home/POLICY.md`; do not build a
custom Terraform provider. Add read-only drift comparison only if the official
API can export these objects reliably without secrets.

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
  disabled, IDS/IPS state is recorded, and every administrator has MFA.
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
- A custom Terraform provider for UniFi ZBF: do not own this maintenance burden.

## Sources

- [UniFi zone-based firewalls](https://help.ui.com/hc/en-us/articles/115003173168-Zone-Based-Firewalls-in-UniFi)
- [UniFi network and client isolation](https://help.ui.com/hc/en-us/articles/18965560820247-Implementing-Network-and-Client-Isolation-in-UniFi)
- [UniFi required ports](https://help.ui.com/hc/en-us/articles/218506997-Required-Ports-Reference)
- [UniFi WLAN security and PMF](https://help.ui.com/hc/en-us/articles/32065480092951-UniFi-WiFi-SSID-and-AP-Settings-Overview)
- [UniFi UPnP guidance](https://help.ui.com/hc/en-us/articles/12648697125783-UniFi-Gateway-UPnP)
- [filipowm/unifi provider](https://github.com/filipowm/terraform-provider-unifi)
