# Impermanence — ephemeral root on btrfs

**Status:** Proposal (skeleton, `TODO(erik)`)

> RFC judgment is human-written; this is scaffolding + decision gates only.

## Motivation

Make each host's mutable state **declared, not accreted**: wipe `/` on boot,
persist only paths the config names. Benefits align with existing fleet ethos
(btrfs-snapshots, reproducibility, sops root-of-trust):

- No config drift / mystery state — if it survives a reboot, it's in the repo.
- Cleaner security posture (transient root; smaller persistent attack surface).
- Cheaper, more honest disaster recovery (persist-set = the real backup set).

## Approach (candidate)

`nix-community/impermanence` + a btrfs subvolume wiped on boot.

- **Wipe mechanism** — `TODO(erik)`: (a) rollback a blank `@root` snapshot in
  the initrd (the "erase your darlings" pattern), or (b) `tmpfs` on `/`. btrfs
  rollback fits the existing disko/btrfs layout; tmpfs caps root at RAM.
- **Persist store** — `environment.persistence."/persist"` with declared
  directories/files; `/nix` and `/persist` are the only durable subvolumes.

## What must persist (starter list — verify per host)

- `/etc/machine-id`, `/var/lib/nixos` (uid/gid map)
- SSH host keys (`/etc/ssh/ssh_host_*`) — **also the sops decrypt anchor**
- **sops age key path** (`~/.config/sops/age/keys.txt`) — losing this bricks
  secret decryption; must be in the persist set or re-provisioned first-boot
- Service state under `/var/lib` (tailscale, containers, ...)
- `/home` — `TODO(erik)`: persist whole home, or go declarative + selective?
- Logs / `/var/log` (already `neededForBoot` on some hosts)

## Risks / open questions (`TODO(erik)`)

1. Any undeclared path silently vanishes on reboot — one-time audit cost + a
   real footgun during rollout.
2. Interaction with `btrfs-snapshots`, `boot-tmpfs`, and per-host `hardware.nix`
   subvolume layouts — must reconcile, not double-manage.
3. sops/age key + SSH host key ordering vs first activation.
4. Rollout host order — `TODO(erik)`: prove on one low-stakes host
   (pathfinder?) before the workstation; laptop last.
5. Home-manager state, `direnv`, editor caches — persist or accept rebuild?

## Decision gates

- [ ] wipe mechanism (btrfs-rollback vs tmpfs)
- [ ] home strategy (whole vs selective)
- [ ] first host + rollout order
- [ ] reconcile with btrfs-snapshots / boot-tmpfs ownership (SRP)

## Non-goals

Not part of this: changing the secrets model (sops stays the root-of-trust),
the backup tiers, or the disko partition scheme beyond adding a persist subvol.
