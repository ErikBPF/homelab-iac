# Telstar — Oracle Ampere A1 host for public-facing personal projects

**Date:** 2026-07-01
**Status:** Ready — host and IaC staged; blocked on Oracle A1 host capacity.
Discovery is the sole acquisition owner. Its declarative service runs the
IaC-owned retry script every minute for up to seven days; no second host or
container may compete for the Terragrunt state lock. Not yet provisioned.
Graduates to `implemented/` on first successful cutover.
**Owner:** erik
**Scope:** A second Oracle Always-Free VM, `telstar` — an **Ampere A1** (aarch64,
2 OCPU / 12 GB) — to expose personal projects to the public internet, kept off
the home LAN. Sibling to `voyager` (the x86 micro off-premise backup receiver);
they share the `profile-oci-guest` boot wiring and the `oracle/` Terragrunt
stack, but serve different purposes.

## 1. Goal

A small, always-free public host for personal projects — reachable from the
public internet, but **not** on the home network. It joins the tailnet as a
`tag:server` peer for management, and public project ingress is opened per
project (Nix firewall + a matching Oracle security-list rule in `homelab-iac`).

Name: `telstar`, after Telstar 1 (1962) — the first active communications
satellite to relay signals across the Atlantic. Fits the fleet's space-tech
naming and its role as the fleet's public relay to the outside world.

## 2. Why A1, not another x86 micro

The x86 E2.1.Micro (voyager) has 1 GB RAM — it **can't kexec** (OOM) and
free-tier `custom-image-count=0` blocks image import, so voyager needed the
`nixos-infect` in-place dance. The A1.Flex has **ample RAM (12 GB)**, so telstar
installs the clean way: **nixos-anywhere (kexec) + disko** from the stock Ubuntu
entrypoint. aarch64 closure **cross-builds on orion** (binfmt); telstar
substitutes. No infect, no image-import workaround.

## 3. Target shape

- `profile-base` + `profile-server` + `profile-oci-guest` (shared OCI boot
  wiring: virtio initrd, serial console, GRUB removable-install).
- aarch64-linux, disko GPT: 512 M vfat ESP at `/boot` + btrfs root
  (`root`/`home`/`nix`/`log` subvols, zstd, noatime). Generations capped at 5
  (512 M ESP).
- SSH on `2222` (fleet OpenSSH policy); break-glass public SSH until the tailnet
  is up.
- Tailscale **client**, `tag:server` (non-expiring OAuth key, fleet-wide rollout).
- Firewall on, `checkReversePath = "loose"`; **no project ports open yet** — each
  is added deliberately with its Oracle security-list rule.
- Rollback guard: `criticalUnits = [sshd, tailscaled]` (public host must stay
  reachable across unattended upgrades).

## 4. What's already staged

NixOS (this flake):

| File | Purpose |
|---|---|
| `modules/hosts/telstar/default.nix` | Registers `configurations.nixos.telstar`; imports base/server/oci-guest + hardware/networking; aarch64; criticalUnits guard. |
| `modules/hosts/telstar/hardware.nix` | disko `/dev/sda` layout, ESP at `/boot`, generation cap, aarch64 platform. |
| `modules/hosts/telstar/networking.nix` | Hostname, DHCP on `ens3`, firewall (no project ports yet), Tailscale client. |
| `modules/meta.nix` (`fleet.hosts.telstar`) | `role = "server"`; `ip`/`tailscaleIp` filled in after provisioning. |
| `modules/deploy-rs.nix` (`telstar` node) | deploy-rs node (magic rollback via IP/sshd). |

Terragrunt (`homelab-iac`):

| Unit | Purpose |
|---|---|
| `oracle/compute-telstar/terragrunt.hcl` | A1.Flex 2 OCPU / 12 GB, own VCN `10.1.0.0/16`, `create_budget = false` (the voyager unit owns the one per-compartment budget). |

Justfile:

| Recipe | Purpose |
|---|---|
| `deploy-telstar` | First install: nixos-anywhere from the Ubuntu entrypoint (`ubuntu@telstar:22`), disko wipe of `/dev/sda`, closure built on orion. |
| `switch-telstar` | Post-install switches (`erik@…:2222`, orion builder). |

## 5. Blocker — Oracle A1 host capacity

The instance can't be created: every launch returns

```text
500-InternalError, Out of host capacity.
```

This is Oracle's free-tier A1 pool being empty in the region, **not** a config
error — telstar dry-evaluates clean and the Terragrunt plan is a valid single
`oci_core_instance` create. Capacity appears randomly; the only known method on
free-tier A1 is persistent retry.

Evidence: a per-minute `terragrunt apply` loop ran **10 h (586 attempts,
2026-06-30 → 07-01)** and a one-shot retry on 2026-07-01 12:11 — **all** returned
"Out of host capacity." Zero slots in the window.

## 6. Scheduled acquisition plan

Use Discovery's declarative systemd service to run the IaC-owned retry script.
It makes one real `terragrunt apply` attempt every 60 seconds for up to seven
days. Discovery is always on, already holds the encrypted OCI credentials, and
is the only host allowed to run this acquisition loop.

Required safeguards:

- one active acquisition service only;
- capacity exhaustion is a normal outcome; auth, state, quota, or plan errors
  are failures and stop retries;
- success reports the public IP and exits zero, ending the retry loop;
- the plan is reviewed before enablement and must contain one
  `VM.Standard.A1.Flex`, 2 OCPU / 12 GB, 50 GB boot-volume instance only;
- no automatic continuation after a PAYG account change;
- optional capacity report is telemetry, not a launch gate.

Implementation and verification details live in the free-resource proposal's
§1e. IaC owns retry behavior; this flake owns the Discovery service.

## 7. Cutover path (when capacity appears)

1. `cd homelab-iac/oracle/compute-telstar && terragrunt apply` succeeds → note
   the assigned public IP.
2. Set `fleet.hosts.telstar.ip` in `modules/meta.nix` → `just fleet-json`.
3. `just deploy-telstar` (nixos-anywhere + disko; wipes `/dev/sda`, converts the
   Ubuntu entrypoint). Closure cross-built on orion.
4. Verify SSH on `2222`, `tailscale status` shows telstar as `tag:server`.
5. Per project: open the Nix firewall port **and** the matching Oracle
   security-list ingress rule in `homelab-iac`; deploy with `just switch-telstar`.
6. Graduate this doc to `implemented/`.

## 8. Open items (post-cutover)

- **Public ingress model.** Decide per-project exposure: direct security-list
  port, or a reverse proxy / Cloudflare tunnel (as the home fleet uses) so raw
  Oracle ports stay closed. Not decided — no project is deployed yet.
- **IP handling.** Ephemeral public IP changes on recreate; `meta.hosts.telstar.ip`
  is filled after provisioning. Consider a reserved public IP if a project needs
  a stable address.
- **Re-arm policy.** Timer stops permanently after successful creation. A future
  recreate or resize requires plan review and explicit re-enable; it must not
  become a permanent background provisioner.

## 9. Links

- Sibling Oracle host (as-built, off-premise backup receiver):
  [`../implemented/2026-06-29-voyager-oracle-offsite-host.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-voyager-oracle-offsite-host.md).
- Deploy standard used for the switch phase:
  [`../implemented/2026-06-30-deploy-rs-as-deploy-standard.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-30-deploy-rs-as-deploy-standard.md).
- Acquisition rationale and phased free-resource roadmap:
  [`2026-07-02-free-tier-cloud-resources.md`](2026-07-02-free-tier-cloud-resources.md).
