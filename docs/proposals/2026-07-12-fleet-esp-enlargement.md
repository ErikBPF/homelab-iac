# Fleet ESP enlargement: risk-triggered migration to 2G

**Status:** Pathfinder, Orion, and Kepler migrated to 2G ESPs on 2026-07-14.
Pathfinder is accepted without a dedicated soak. Laptop migration is cancelled
because that machine will be replaced. Discovery is the only remaining
existing-host migration and retains independent rehearsal and approval gates.

## Policy

Future disko installs already allocate a 2G ESP. Existing 512M ESPs are not a
fleet-wide reinstall campaign. A host migrates only when:

- upgrade preflight cannot fit candidate + one known-good generation + 25%
  reserve; or
- another approved reinstall creates a safe opportunity.

Projected reserve below 50% warns. Below 25% blocks activation. Cleanup cannot
override this rule.

Original scope covered the existing disko-managed x86 physical hosts:
`pathfinder`, `laptop`, `orion`, `kepler`, and `discovery`. Laptop is now out of
scope; its replacement receives the 2 GiB layout on first install. Archinaut uses a
Raspberry Pi firmware partition; Voyager and Vanguard retain provider layouts;
Telstar will start with 2G if provisioned.

## Shared destructive contract

Each host is an independent migration slice. Never run two concurrently.

Before destruction, an automated fail-closed preflight must capture:

- disk model, serial, partition, filesystem, and mount-source inventory;
- actual and projected ESP capacity;
- a fresh encrypted backup after the migration freeze;
- successful multi-class restore drill and restore-drill age no greater than 90
  days: one bootstrap credential, one dotfile, one document, and one large file
  when those classes exist;
- installer media, console or physical access, sops key, SSH key, host closure,
  and cache availability;
- host-specific data-survival assertions.

The restore drill reads selected files directly from the encrypted snapshot,
hashes them, and writes no full-home restore. One representative hash remains
the minimum emergency gate when a class is absent, but a snapshot listing alone
is never restore proof.

Recovery is forward-only, not rollback. If installation fails, reinstall the
same host and restore it. Stop the fleet migration until that host is healthy.

## Host hazards

- **Pathfinder:** one `/dev/sda`; full wipe is approved. Windows no longer
  exists. Clean workstation bootstrap; encrypted `/home/erik` safety snapshot
  goes to Kepler and a representative file must restore before wipe.
- **Laptop:** one encrypted disk and the normal control workstation. Another
  host must drive installation; preserve non-reproducible home data first.
- **Kepler:** wipe only the OS M.2. ZFS pools must remain outside the destructive
  graph and import cleanly afterward.
- **Orion:** current full disko graph includes `/projects` and `/opt/models`.
  The normal installer is forbidden. Build a reviewed boot-disk-only installer
  module and prove data disks are absent from its destructive graph.
- **Discovery:** root RAID members are destructive; vault disk survives only if
  live inventory proves it is outside disko. Prove Docker data ownership and
  restore representative state before approval.

## Pathfinder execution slice (completed)

Pathfinder was the first approved migration. The planned installer-media path
evolved to `nixos-anywhere --force-kexec` from the live system after port 22 was
confirmed unavailable. The same disk identity, backup, closure, and passphrase
gates remained in force.

1. Boot the current system and make it reachable.
2. Run read-only inventory and ESP projection.
3. Freeze writes to non-reproducible home data.
4. Create an encrypted `/home/erik` safety snapshot on Kepler.
5. Restore a representative file into a temporary directory and compare it.
6. Build the Pathfinder closure and verify trusted installer media.
7. Present the evidence bundle. Destructive `/dev/sda` wipe is already approved
   for this slice, but any failed gate stops execution.
8. Laptop drives `nixos-anywhere` while Pathfinder runs trusted NixOS installer
   media.
9. Use LUKS passphrase only. Do not log or place it in command arguments.
10. Boot, restore only non-reproducible data, then verify networking, SSH,
    Syncthing, Home Manager, GPU/session health, boot counting, revision, failed
    units, and the 2G ESP.

Pathfinder's obsolete Windows dual-boot and FIDO2-unlock configuration must be
removed with this slice.

## Pathfinder findings incorporated into later slices

Pathfinder completed on 2026-07-14. Its encrypted Restic snapshot `00eba53c`
stored 28.324 GiB on Kepler; a representative file was streamed back and its
SHA-256 matched before the wipe. The completed migration exposed bootstrap
requirements that are now gates for later hosts:

- declare `users.mutableUsers = false`; otherwise an install that initially
  lacks decrypted `hashedPasswordFile` creates a locked user and later
  activations preserve it;
- stage the sops age key, verify first-boot decryption, require `passwd -S` to
  report a password-bearing account, and prove an actual greeter login;
- create every configured Syncthing folder root as the target user before
  Home Manager runs; `.stignore` symlink creation must not leave root-owned
  parents;
- remove a stale Tailscale machine before enrolling its replacement;
  workstations remain user-owned and use interactive enrollment because the
  fleet OAuth credential is intentionally scoped to `tag:server`;
- record and republish the new Tailscale IP in the fleet SSOT;
- build only on declared remote builders (`--max-jobs 0`); the control laptop
  may evaluate and orchestrate but must not compile closures;
- judge activation by resulting generation and service evidence. A failed
  AppArmor reload can make `switch-to-configuration` return nonzero after the
  generation and secrets were applied, so diagnose that unit explicitly rather
  than treating the misleading sudo footer as the cause;
- post-switch evidence must include zero failed units, Home Manager, Syncthing,
  sops staging cleanup, Tailscale name/IP, account state, greeter login, and ESP
  capacity. Pathfinder finished with a 2 GiB ESP and 78% projected reserve.

The following implementation improvements landed from those findings:

- the generic deploy escape hatch now uses declared fleet builders and
  `--max-jobs 0`, preventing laptop compilation;
- the fleet user module enforces immutable declarative passwords and provides a
  silent local password-hash rotation path that writes only sops ciphertext;
- the Syncthing topology creates all folder roots with user ownership before
  linking `.stignore`;
- Pathfinder has fingerprint-pinned SSH host-key replacement, bootstrap/login
  diagnostics, and explicit user-owned Tailscale enrollment recipes;
- Pathfinder's new Tailscale address, `100.102.248.13`, is recorded in the fleet
  SSOT.

## Orion migration (completed)

Live inventory on 2026-07-14 corrected the assumed `sdX` mapping. Orion has:

- Force MP510 NVMe, serial `19458242000129183963`: current 512 MiB ESP and
  Btrfs root/home/nix/log; this is the only migration target;
- SanDisk SSD PLUS, serial `193181805834`: Btrfs `/projects`, filesystem UUID
  `d4511ef9-7f62-4f0f-86d2-ee015344c289`;
- Kingston SV300S37A480G, serial `50026B724709FD21`: ext4 `/opt/models` and the
  Steam bind source, filesystem UUID
  `88a7f0d3-2fa2-4354-a4cd-8cab451dce85`.

The filesystem design remains unchanged: Btrfs is retained for the NVMe system
and `/projects`; ext4 is retained for model and Steam data. Filesystem redesign
would add unrelated failure modes to an ESP migration.

An `orion-esp-installer` configuration now force-replaces the normal disko disk
graph with only
`/dev/disk/by-id/nvme-Force_MP510_19458242000129183963`. The two SATA filesystems
are mounted by UUID but are absent from the destructive graph. The generated
disko script passed a fail-closed graph proof, and the installer toplevel passed
a dry-run evaluation. The normal Orion installer remained forbidden for this
migration.

Orion's home is approximately 117 GiB. The encrypted backup recipe excludes
the nested SATA mounts and requires four successful selective restores: the
sops age key, a dotfile, the flake document, and a 5.3 GiB model shard. This
backup and restore drill completed before destructive approval. Orion then
migrated only the Force MP510 NVMe. `/projects` and `/opt/models` survived on
their original SATA filesystems and mounted by UUID after boot. The generated
host key changed during reinstall; builder trust was repaired only after its
new fingerprint was verified. The controller laptop orchestrated but did not
build the closure.

## Kepler migration (completed)

Live inventory corrected Kepler's volatile `sdX` mapping immediately before
the wipe. The only destructive target was Toshiba M.2 serial
`58SF70G0F5WP`; the four-disk `fast-pool`, five-disk `bulk-pool`, and two cache
SSDs were excluded from the generated disko graph by a fail-closed proof.

The encrypted OS-state snapshot on Orion is `6a5aa2da`. Four selective restore
classes passed before destruction, including SSH identity, Tailscale state,
sops age key, and a 5.3 GiB model shard. Orion built the Kepler closure with
`--max-jobs 0`; the control laptop only orchestrated. `nixos-anywhere
--force-kexec` installed the 2G ESP and Btrfs root while staged extra files
preserved SSH, Tailscale, and sops identity.

After boot, both ZFS pools imported ONLINE with zero errors and `/fast` and
`/bulk` mounted from their original members. The 134 GiB home tree was restored
from the verified snapshot; the representative large-file SHA-256 matched.
Home Manager was reasserted after restore, Syncthing/NFS resumed, and all eight
currently declared AI/docs containers reached healthy state. The historical
`f5-tts-server` container was correctly absent because current config retired
it on 2026-07-14.

## Next steps

1. Retain Pathfinder, Orion, and Kepler snapshots according to normal backup
   policy; no migration-specific soak gates further fleet work.
2. Do not migrate the current laptop. Its replacement receives the 2 GiB ESP
   layout during first installation.
3. Execute Discovery preparation through the independent
   [Discovery ESP migration plan](2026-07-14-discovery-esp-migration.md): prove
   the root RAID destructive graph, vault exclusion, cold Docker recovery,
   encrypted restores, and OpenBao/Harbor/Compose recovery order.
4. Discovery destruction remains blocked pending its evidence manifest and a
   separate explicit approval.

## Later-host approval

Pathfinder approval does not authorize another host. Every later destructive
migration needs its own evidence and explicit per-host approval.
