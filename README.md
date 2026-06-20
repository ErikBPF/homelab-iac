# homelab-iac

Declarative, git-versioned **homelab infrastructure-as-code** (OpenTofu +
Terragrunt). Three components, each under its own top-level dir:

- **`unifi/`** — the UniFi network layer (`filipowm/unifi`): networks/VLANs,
  WLANs, DNS, DHCP reservations. The substrate the fleet sits on.
  Environments: `home` (UDM Pro/SE at `https://192.168.10.1`) and `lab` (stub).
- **`tailscale/`** — the Tailscale tailnet (`tailscale/tailscale`): ACL policy
  file + DNS (nameservers, MagicDNS, search paths). The overlay-network layer.
- **`cloudflare/`** — the public edge (`cloudflare/cloudflare`): DNS records for
  `pastelariadev.com` (tunnel CNAMEs). The public-DNS layer.

Project scaffolding follows the `datafoundation-iac` devenv/Terragrunt pattern.

## Where this fits — the homelab fleet

This repo is the **network substrate**; the sister repos run *on top of* the
VLANs, reservations, and DNS defined here. [`desktop-nixos`](https://github.com/ErikBPF)
is the source of truth for the **hosts**; `homelab-iac` is the source of truth
for the **network they live on**.

| Sister repo | Owns | Coupling to this repo |
|---|---|---|
| `desktop-nixos` | Fleet host OS (kepler, orion, discovery, pathfinder, laptop…) | **Addressing contract** — the fixed-IP reservations here assign the IPs those hosts use (e.g. `kepler` → `.230`, `homeassistant` → `.205`, `archinaut` → `.225`, `nix-erik` → `.125`). Change a host's IP in one repo, update the reservation in the other. |
| `servarr` | Container stacks on kepler/discovery/orion | Containers talk over the LAN/VLANs defined here; ingress resolves via the static DNS records. |
| `hermes-flake` | hermes-agent on kepler | Runs on a host addressed by a reservation here. |
| `home-assistant-config` | HA app config | HA host = the `homeassistant` reservation (`.205`); voice backend on kepler. |
| `klipper-biqu` (→ `archinaut`) | 3D-printer host config | Printer host = the `archinaut` reservation (`.225`). |

Rule of thumb: when a host IP or a service hostname changes, the matching half
is a **reservation** or **DNS record** in this repo. Keep them in sync.

## Coverage & gaps

**Managed in code** (zero-diff import): _UniFi_ — networks (`Default`, `Main`),
WLANs (×3), static DNS (×2), DHCP reservations (×22); _Tailscale_ — ACL policy
file (`tailscale/acl/policy.hujson`) + DNS (nameservers, MagicDNS, search paths);
_Cloudflare_ — public DNS for `pastelariadev.com` (3 tunnel CNAMEs) + the
`homeassistant-remote-access` tunnel ingress (ha, rpg);
_AdGuard_ — DNS rewrites, `user_rules`, blocklist filters.

This gives DNS-as-code at every layer: **public** (Cloudflare) · **LAN** (UniFi
static DNS) · **tailnet** (Tailscale MagicDNS) · **filtering** (AdGuard).

> **AdGuard ownership split:** Terraform owns rewrites / user_rules / filters via
> the API. The **base config** (DNS upstreams, dhcp, tls, querylog/stats) stays
> in servarr's `AdGuardHome.yaml` — `adguard_config` can't be managed cleanly
> (its update rejects the disabled-DHCP block). `just sync-servarr` excludes that
> file so a sync can't clobber Terraform. AdGuard rewrites the YAML at runtime,
> so its base config effectively self-persists on the host.

**Not manageable with the `filipowm/unifi` provider — stays UI-managed:**

- **OpenVPN-client network `OpenVPN USA`** (NordVPN). The `network` resource
  supports only `purpose = corporate|guest|wan|vlan-only` — there is no
  `vpn-client` purpose and no OpenVPN-client resource. The provider exposes only
  `setting_teleport` (WireGuard) and `setting_magic_site_to_site_vpn` (IPsec
  S2S), neither of which is an outbound OpenVPN client. Also holds NordVPN
  credentials. (Its policy route is currently **disabled** anyway.)
- **Traffic routes / policy-based routing** — no `traffic_route` resource.
- **WLAN groups** — no resource (WLANs bind to AP groups, which we do set).
- **MikroTik switches** (`192.168.10.2` `Mikrotik servidor`, `.3` `Mikrotik Sala`)
  run **swOS** — web-UI only, no API/SSH/REST, so no Terraform provider applies
  (`terraform-provider-routeros` needs RouterOS). They are captured here only as
  DHCP reservations. (RouterOS migration would be required to manage them as code,
  and only CRS-series hardware can run it.)

**At defaults — not worth importing** (would add noise, no real config): the
predefined `user_group` (Default), `radius_profile` (Default), firewall zones,
and the global `setting_*` (mgmt, ntp, country, …) are all stock. Import a
`setting_*` module only once you actually customize that setting.

**Empty — nothing to import:** static routes, port profiles, firewall
rules/groups, port-forwards, dynamic DNS, RADIUS accounts.

## Layout

```
.
├── devenv.nix / devenv.yaml / .envrc   # devenv: opentofu, terragrunt, tflint, jq
├── .env.example                        # secrets template (copy -> .env, gitignored)
├── unifi/
│   ├── root.hcl                        # root: generates provider + encryption + backend
│   ├── default_flags.hcl               # allow_insecure (self-signed UDM cert)
│   ├── environments/<env>/
│   │   ├── env.hcl                      # env name, api_url, site
│   │   └── <stack>/terragrunt.hcl       # one live unit per stack
│   └── modules/<stack>/                 # network, wlan, dns, reservations, …
├── tailscale/
│   ├── root.hcl                        # root: tailscale provider + encryption + backend
│   ├── acl/  (terragrunt.hcl + policy.hujson)   # tailnet policy file
│   ├── dns/  (terragrunt.hcl)                    # nameservers, MagicDNS, search paths
│   └── modules/{acl,dns}/
└── cloudflare/
    ├── root.hcl                        # root: cloudflare provider (token-var) + encryption + backend
    ├── dns/  (terragrunt.hcl)                    # public DNS records (tunnel CNAMEs)
    ├── tunnel/  (terragrunt.hcl)                  # homelab tunnel ingress rules
    └── modules/{dns,tunnel}/
```

## Setup

1. `cp .env.example .env` and fill `UNIFI_API_KEY_home` (UniFi → Settings →
   Control Plane → Integrations → Create API Key; Network app ≥ 9.0.108).
2. `direnv allow` (or `devenv shell`) — loads the toolchain + `.env`.

## Apply rule (important)

**Never apply over Wi-Fi.** Network/VLAN/firewall changes can drop the
connection mid-apply and lock you out. Run `plan`/`apply` from a **wired** host
on the controller's LAN.

## Workflow

```
cd unifi/environments/home/network
terragrunt plan
terragrunt apply
```

Whole environment: `cd unifi/environments/home && terragrunt run --all plan`.

## Phase 1 — import current state (do this first)

Goal: reflect the *existing* live config into code and reach a clean plan
(no diff). Nothing is changed.

Per stack:

```
cd unifi/environments/home/<stack>
# discover ids (e.g. via the provider data sources or the controller API), then:
terragrunt plan -generate-config-out=generated.tf   # scaffold resource bodies
# transcribe values into the module inputs, import each resource into state:
terragrunt import 'unifi_<resource>.this["<key>"]' <id>
terragrunt plan                                      # must show: no changes
```

The `network` module is the worked example; the other modules are skeletons whose
`main.tf`/`variables.tf` get filled from the generated config, then refactored to
the same typed-map + `for_each` shape.

## Notes

- The `filipowm/unifi` provider drives the controller's **internal** API and can
  drift across Network-app upgrades — pin the provider (`default_flags.hcl`) and
  re-`plan` after each controller update before trusting `apply`.
- State is **local**, under `unifi/.state/` (gitignored), and **encrypted at
  rest** (OpenTofu AES-GCM + PBKDF2). The passphrase is `UNIFI_STATE_PASSPHRASE`
  in `.env` — **back it up**; losing it makes state undecryptable. To migrate a
  fresh/plaintext state, temporarily add an `unencrypted` `fallback` to the
  `state`/`plan` blocks in `root.hcl`, run `apply -refresh-only`, then remove it.
- Secrets never touch disk/git: API key, WLAN passphrases, and the state
  passphrase all flow shell `.env` → Terragrunt input → `TF_VAR_*`.
- **Pre-commit** (devenv `git-hooks`): `tofu fmt`, `terragrunt hcl format`, and
  `tflint` run on commit. Active after `direnv allow` / `devenv shell`.
