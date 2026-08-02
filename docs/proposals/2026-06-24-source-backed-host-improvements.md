# Source-Backed Host Improvement Review

**Status:** Graduated 2026-07-30 — P0 exposure audit/cleanup and P1 deploy-rs
adoption delivered. The remaining sudo, NFS, sandboxing, state-inventory, and
acceptance-test work is split into H1–H5 in
[`2026-07-02-open-decisions-and-work.md`](2026-07-02-open-decisions-and-work.md);
this broad review is no longer an executable program.
**Audience:** Maintainers of `desktop-nixos`
**Post-read action:** Pick the next security, performance, and usability improvements per host, with external references for the recommendations.

## 1. Method

This review combines:

- Local inspection of the current host modules, role profiles, networking, security, storage, deployment, and orchestration modules.
- Current upstream/community documentation for NixOS, sops-nix, disko, impermanence, nixos-anywhere, deploy-rs, Colmena, SrvOS, and Tailscale.
- Attempts to search Reddit for NixOS homelab patterns. Reddit results were not reliably accessible through the available search index during this review, so no Reddit-specific claim is treated as evidence. The durable sources below carry the recommendations.

The useful online pattern is consistent: mature NixOS homelabs converge on reusable server profiles, declarative disk/install flows, encrypted secrets in Git, explicit remote deployment tooling, host-specific firewall/ACL policy, and some form of rollback or activation health check.

## 2. Current host purposes

| Host | Current purpose | Main risk surface |
|------|-----------------|-------------------|
| `pathfinder` | Desktop workstation, Hyprland, Syncthing, NFS client, Tor monitor | Desktop apps, browser, local ports 80/443, user session state |
| `laptop` | Mobile desktop, Hyprland, Syncthing, NFS client, vendor agent, roaming Tailscale | Roaming network exposure, agent trust, monitor config complexity |
| `orion` | HTPC, AMD GPU inference, build server, binary cache, compose workloads | Trusted builder/cache role, rootless container workloads, performance tuning drift |
| `discovery` | 24/7 home server, DNS/ingress, HAOS VM, Docker compose, monitoring, IaC drift, media services | Broadest exposed service surface, Docker firewall behavior, rootful Docker group |
| `kepler` | NAS, GPU AI inference, k3s MicroVM cluster, NFS/SMB, backup target | Storage/export permissions, GPU containers, k3s cluster, NFS root mapping |
| `archinaut` | RPi3 print host for Klipper/Moonraker/Mainsail | Low memory, physical device control, web UI, upgrade risk |
| `archinaut-base` | Rescue/fallback SD image | Must stay minimal and reliable |

## 3. What is already strong

### Security

- SSH is on a non-default port, disables root login, disables password and keyboard-interactive auth, and disables forwarding by default.
- The firewall is enabled fleet-wide; NixOS documents that its firewall is enabled by default and blocks incoming services unless opened explicitly.
- Fail2ban is enabled fleet-wide; the NixOS wiki notes that the default module includes an SSH jail, which is enough for basic SSH rate limiting when only SSH is exposed.
- AppArmor and auditd are enabled in the base profile.
- Secrets use sops-nix. Upstream sops-nix explicitly supports encrypted secrets in version control, eval-time secret/config checking, atomic secret activation, rollback support, and Home Manager integration.
- Auto-upgrades have a local rollback guard that checks critical systemd units.
- CI evaluates every main x86 host and runs a k3s smoke test.

### Performance

- Orion is tuned as a specialized builder/inference host, including build offload, binary cache warming, AMD GPU tuning, and disabled runtime tuners that would violate its performance assumptions.
- Kepler avoids THP=always because ZFS is the primary daily workload.
- Store hardlink optimization and garbage collection are enabled globally; NixOS storage docs recommend store optimization and GC because the Nix store otherwise grows steadily.
- Kepler pins NFS auxiliary RPC ports so firewalling is deterministic.

### Usability

- The repo has `just` recipes for build, deploy, verification, bootstrap, cache, and k3s workflows.
- nixos-anywhere/disko patterns are already partially adopted for bootstrap.
- Host purposes are documented in the README.
- The rescue `archinaut-base` image is a good operational pattern for low-resource physical hosts.

## 4. Priority improvements

### P0 - Fix broad or surprising exposure

#### 4.1 Remove desktop HTTP/HTTPS openings unless actively used

`pathfinder` allows TCP 80 and 443. If those ports are only for occasional local development, remove them from the persistent firewall and add a temporary `just dev-open-ports` or per-service `openFirewall` instead.

Rationale: NixOS firewall policy is explicit allow-listing. Persistent desktop web ports increase attack surface without matching the host purpose.

Applies to:

- `pathfinder`
- Possibly `orion`, if ports 80/443 are no longer serving HTPC or AI endpoints

#### 4.2 Make Docker firewall bypass explicit on discovery

Discovery uses rootful Docker. The NixOS firewall page warns that Docker may overwrite firewall rules. This matters because discovery is the public ingress/DNS/media host and has the broadest compose surface.

Recommended work:

- Document which discovery services are intentionally reachable from LAN, Tailscale, and internet ingress.
- Add a `just verify-firewall discovery` recipe that runs `ss -tulpn`, `nft list ruleset` or equivalent, and Docker port mapping inspection.
- Prefer reverse proxy exposure over host port publishing for compose services.
- Consider Docker daemon hardening and network-level allow lists for published ports.

Do not rush a migration back to rootless Podman while the btrfs/userns issue still exists. The current rootful Docker choice is operationally justified; the missing piece is auditable exposure.

#### 4.3 Tighten `sudo`

The current base config has passwordless wheel and a global 60-minute timestamp. For desktops that may be acceptable, but for servers it is unusually permissive.

Recommended work:

- Split sudo policy by profile.
- Desktops can keep ergonomic sudo if desired.
- Servers should use shorter timestamp, command-specific passwordless rules where needed, or `doas`/sudo rules scoped to exact operations.
- Archinaut should be especially narrow because it controls physical hardware.

### P1 - Adopt a real fleet deploy layer

The repo currently uses `nixos-rebuild` and custom `just` recipes. That works, but other multi-host NixOS setups commonly use a thin deployment layer:

- `deploy-rs` supports flake-targeted deploys and rolls back successful deploys if a multi-target run later fails.
- Colmena is a stateless NixOS deployment tool with parallel deployment support.
- nixos-anywhere handles remote install flows and reuses stored disk/Nix configurations.

Recommended work:

- Add one deploy layer as an optional path, not a replacement for current recipes.
- Start with `deploy-rs` if rollback semantics are more important.
- Start with Colmena if fleet selection/tagging and parallel deploy ergonomics are more important.
- Keep the current `upgrade-health-check` because it validates service health after activation; deploy tools validate activation mechanics, not your application invariants.

Best first slice:

- Add deploy definitions for `orion`, `discovery`, `kepler`, and `pathfinder`.
- Keep `archinaut` on manual/supervised deploy until the print-stack health checks are mature.

### P1 - Make Tailscale ACLs/grants testable

Tailscale docs now recommend grants for new tailnet policy and state that ACLs are deny-by-default only when you define policy; otherwise the default policy allows all. They also emphasize directional, locally enforced access.

You already have `tailscale-acl.json` and narrow subnet routes on discovery. The improvement is testing:

- Add Tailscale policy tests for the admin devices, discovery subnet router, NAS access, SSH access, and service ingress.
- Move toward grants when you next touch the tailnet policy.
- Model host roles as tags: desktop, server, nas, ingress, builder, printer.
- Avoid `--accept-routes` on hosts that do not need subnet routes.

### P1 - Revisit NFS export permissions on kepler

Kepler exports `/fast` to LAN and Tailscale with `rw` and `no_root_squash`. That is convenient but broad for a NAS and AI model store.

Recommended work:

- Keep `no_root_squash` only for the k3s CSI paths that require root-owned PV setup.
- For LAN/Tailscale clients, prefer `root_squash` and explicit writable subdirectories.
- Split model cache, scratch, media, and k8s PV roots into separate exports with separate policies.
- Add a NAS verification recipe that mounts each export from a non-root client and checks expected read/write/chown behavior.

This is the highest-value host-specific security improvement for kepler.

### P2 - Add impermanence selectively, not fleet-wide

Impermanence is popular in the NixOS ecosystem because it forces persistent state to be declared. Upstream describes it as keeping selected files/directories while discarding the rest. However, the tmpfs-root approach has real drawbacks: large downloads can exhaust memory or apparent disk space, and crashes before persistence can lose data.

Recommended work:

- Do not apply tmpfs-root impermanence to kepler, discovery, or orion first.
- Consider it for `pathfinder` or `laptop` only after the persistence set is known.
- A safer first step is "opt-in state inventory": list every mutable path that matters per host, without changing mount topology.
- For servers, use btrfs/ZFS snapshot rollback patterns before tmpfs-root.

### P2 - Improve service sandboxing

Several custom systemd services run scripts that touch Git repos, decrypted env files, Docker sockets, SSH keys, or storage exports.

Recommended work:

- Add `systemd-analyze security` checks for custom services.
- Harden custom units with `ProtectSystem`, `ProtectHome`, `PrivateTmp`, `NoNewPrivileges`, `RestrictAddressFamilies`, `ReadWritePaths`, and dedicated users where practical.
- Start with:
  - `homelab-iac-drift`
  - `nix-cache-builder`
  - `docker-recover`
  - `klipper-config-backup`
  - `restic-tofu-state-onfail`

Do this gradually. Some services need broad access by design; the goal is explicit exceptions, not maximum sandboxing at the expense of operability.

### P2 - Add host acceptance tests beyond eval

CI currently evaluates host drv paths and runs a k3s smoke test. That is good, but a few host contracts can be tested cheaply:

- SSH config renders with port 2222 and password auth disabled.
- Firewall expected port sets per host.
- No desktop profile imports on pure servers except intentional exceptions.
- SOPS secrets referenced by modules exist in `secrets.yaml`.
- `system.autoUpgrade` hosts define critical units.
- Docker hosts have an explicit firewall exposure manifest.

These can be lightweight Nix checks or shell checks.

## 5. Host-by-host recommendations

### Pathfinder

Purpose: desktop workstation.

Recommended:

- Remove persistent 80/443 firewall openings unless a standing local service needs them.
- Keep zram and btrfs snapshots.
- Consider selective impermanence only after a state inventory.
- Move monitor/workspace layout into a host `home.nix` or display profile so the host `default.nix` stays an assembly file.

Security posture: good baseline; main issue is unnecessary open web ports.

### Laptop

Purpose: mobile desktop.

Recommended:

- Audit the vendor `ampagent` module separately. It is the highest-trust unknown on the mobile host.
- Consider stricter Tailscale route acceptance. A roaming laptop should only accept routes it actively needs.
- Keep firewall limited to Syncthing.
- Move monitor/workspace layout out of `default.nix`.
- Consider impermanence later, but only after persistence for browser profiles, Obsidian, SSH/GPG/SOPS, Syncthing, development caches, and vendor agent state is known.

Security posture: good firewall baseline; main risk is roaming network plus vendor agent.

### Orion

Purpose: HTPC, builder, binary cache, AMD GPU inference.

Recommended:

- Treat Orion as infrastructure, not just a desktop-ish host. It signs/serves cache material and accepts builder SSH.
- Restrict port 5000 cache access to LAN/Tailscale explicitly if not already enforced elsewhere.
- Replace `git reset --hard origin/main` in the cache warmer with a safer fetch of a pinned ref or a dedicated worktree. The service runs as root and executes builds from a mutable repo checkout.
- Document each kernel/sysctl tuning as either "inference invariant", "gaming invariant", or "temporary experiment".
- Consider deploy-rs/Colmena rollout here first because it is a high-value rebuild target.

Security posture: strong SSH baseline; main risks are cache trust, root service Git checkout, and open HTTP cache.

### Discovery

Purpose: 24/7 ingress, DNS, HAOS, Docker compose, monitoring, media, IaC drift.

Recommended:

- Create a discovery exposure manifest: every published port, reverse proxy hostname, Docker network, and expected source network.
- Add Docker firewall verification because Docker may modify firewall rules.
- Keep rootful Docker for now, but tighten group membership and document why each user needs Docker access. Docker group is effectively root-equivalent.
- Add service sandboxing to drift, compose sync/decrypt, Docker recovery, and notification helpers.
- Consider splitting compose stacks by trust zone: ingress/DNS, media, observability, AI/tools, experimental.
- Add post-deploy checks for DNS, SWAG/ingress, HAOS, Docker health, and monitoring ingest.

Security posture: broadest attack surface. The design is practical, but it needs exposure inventory and Docker-aware verification.

### Kepler

Purpose: NAS, AI inference, k3s MicroVM platform, backup target.

Recommended:

- Narrow NFS `no_root_squash` to k3s CSI exports only.
- Split NAS exports by data class and write policy.
- Add k3s cluster lifecycle recipes for scale-down, reset, and node cleanup if not already planned.
- Make GPU container runtime verification a post-deploy check.
- Keep THP default for ZFS unless inference measurements prove otherwise.
- Add NAS backup restore tests, not just backup jobs.

Security posture: good service segmentation, but NFS export policy is the main hardening opportunity.

### Archinaut

Purpose: print host, low-resource RPi3.

Recommended:

- Keep `archinaut-base` minimal and never import monitoring or print stack.
- Add a print-host exposure manifest: Mainsail, Moonraker, webcam, Klipper API, HA power integration.
- Consider Tailscale-only access for Moonraker/Mainsail if LAN browser access is not required.
- Add systemd hardening to webcam and backup services.
- Keep auditd disabled on the Pi if it causes boot/runtime failures; low-memory reliability wins.
- Add a post-upgrade print-stack health check that verifies Klipper, Moonraker, webcam, and disk free space.

Security posture: operational reliability is the security feature here. Avoid heavy agents and broad service exposure.

### Archinaut-base

Purpose: rescue image.

Recommended:

- Keep only SSH, Tailscale, SOPS bootstrap, and enough hardware support to converge to the full host.
- Do not add logging/monitoring agents.
- Add a periodic reminder in docs to build the rescue image after major kernel/boot changes.

## 6. Cross-cutting improvements

### 6.1 Source of truth for exposed services

Add a generated or hand-maintained table:

| Host | Port | Protocol | Interface/source | Service | Reason |
|------|------|----------|------------------|---------|--------|

This should include firewall openings, Docker-published ports, NFS/SMB, Tailscale routes, and reverse-proxy hostnames.

### 6.2 Fleet role profiles

SrvOS is a useful analogy: it provides opinionated server profiles and role modules rather than making every host repeat base server concerns. Your repo already has `profile-base`, `profile-desktop`, and `profile-server`; extend that with narrow role overlays:

- `role-ingress`
- `role-nas`
- `role-builder`
- `role-gpu-inference`
- `role-k3s-host`
- `role-printer`

These should be small composition modules, not giant abstractions.

### 6.3 Deployment matrix

Add a deploy policy table:

| Host | Auto-upgrade | Manual switch | Fleet switch | Reboot allowed | Extra health checks |
|------|--------------|---------------|--------------|----------------|---------------------|

Kepler and archinaut should stay more supervised than desktops. Discovery should deploy only when ingress/DNS checks are ready.

### 6.4 Secrets lifecycle

sops-nix is already the right tool. Improve around it:

- Per-host secret ownership and mode review.
- Secret existence checks in CI for all declared `sops.secrets`.
- Rotation checklist for Tailscale auth keys, cache signing key, Samba password, restic keys, and Cloudflare/provider tokens.
- Prefer host SSH-derived age recipients for machine secrets where possible, matching sops-nix guidance.

### 6.5 Backup restore drills

Backups exist for important state. The missing usability/security control is restore proof.

Add recipes:

- `just restic-check tofu-state`
- `just restic-restore-test tofu-state`
- `just nas-snapshot-list kepler`
- `just syncthing-status <host>`

Run restore drills quarterly or after storage changes.

### 6.6 Observability as acceptance criteria

Grafana Alloy is already present on most hosts. Add explicit post-deploy checks:

- Logs arriving from every host that should run Alloy.
- Node metrics present.
- Critical timers active.
- Failed units zero or expected.
- Disk pressure thresholds visible.

For archinaut, do not force Alloy; use lightweight checks from another host.

## 7. Recommended implementation order

### Slice 1 - Exposure inventory

Write `docs/service-exposure.md` and fill it from current firewall, Docker compose, Tailscale, NFS/SMB, and reverse proxy settings.

Verify:

- `ss -tulpn` on each host.
- Docker/Podman published ports.
- Tailscale ACL/grant policy tests.

### Slice 2 - Desktop port cleanup

Remove unexplained 80/443 openings from desktop hosts.

Verify:

- `just dry pathfinder`
- `just dry laptop`
- Local dev workflow still has an explicit temporary port path.

### Slice 3 - Kepler NAS export hardening

Split exports and remove broad `no_root_squash`.

Verify:

- LAN client mount.
- Tailscale client mount.
- k3s CSI PV creation.
- Expected write/chown behavior.

### Slice 4 - Discovery Docker/firewall audit

Add Docker-aware firewall verification and service exposure docs.

Verify:

- DNS works.
- SWAG routes work.
- Docker health checks pass.
- Unexpected published ports fail the check.

### Slice 5 - Fleet deployment layer

Prototype deploy-rs or Colmena for two hosts.

Verify:

- One desktop deploy.
- One server deploy.
- Failed health check rolls back or blocks promotion.

### Slice 6 - Service sandboxing pass

Harden one custom service at a time.

Verify:

- `systemd-analyze security` improves.
- Service still performs its job.
- Failure mode remains observable.

## 8. Source notes

- [NixOS Firewall wiki](https://wiki.nixos.org/wiki/Firewall): NixOS firewall is enabled by default, blocks incoming services unless allowed, supports interface-specific rules, and warns that Docker may overwrite firewall rules.
- [NixOS Fail2ban wiki](https://wiki.nixos.org/wiki/Fail2ban): fail2ban scans logs, ships a preconfigured SSH jail on NixOS, and supports retry, ban time, ignore list, and ban increment tuning.
- [NixOS Distributed build wiki](https://wiki.nixos.org/wiki/Distributed_build): distributed builds require SSH and Nix config on both sides; the wiki recommends avoiding direct root SSH to remote builders when not required.
- [NixOS Storage optimization wiki](https://wiki.nixos.org/wiki/Storage_optimization): store optimization and garbage collection are normal controls for Nix store growth.
- [sops-nix](https://github.com/Mic92/sops-nix): supports atomic, declarative, reproducible secret provisioning, encrypted secrets in Git, evaluation-time checking, Home Manager integration, and age keys derived from SSH keys.
- [disko](https://github.com/nix-community/disko): declarative partitioning/formatting for reproducible installs and crash recovery; supports LUKS, btrfs, ZFS, tmpfs, mdadm, and more.
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere): remote NixOS install over SSH, including partitioning/formatting, installation, and optional extra files.
- [impermanence](https://github.com/nix-community/impermanence): keeps selected files/directories while discarding the rest; tmpfs-root is easy but can run out of memory/disk space and lose unpersisted data on crash.
- [deploy-rs](https://github.com/serokell/deploy-rs): flake-native multi-profile deploy tool with multi-target rollback behavior.
- [Colmena](https://github.com/nix-community/colmena): stateless NixOS deployment tool with parallel deployment support.
- [SrvOS](https://github.com/nix-community/srvos): analogous community pattern for reusable opinionated server profiles and role modules.
- [Tailscale ACL docs](https://tailscale.com/docs/features/access-control/acls): recommends grants for new policy, describes deny-by-default behavior when policy is defined, and notes ACLs are directional and locally enforced.
