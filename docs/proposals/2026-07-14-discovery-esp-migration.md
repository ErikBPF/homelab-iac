# Discovery ESP migration: rehearsed recovery of the fleet control plane

**Status:** Plan — live inventory captured 2026-07-14; destructive migration is
blocked until every rehearsal and approval gate below passes.

**Audience:** The maintainer executing Discovery's reinstall during a controlled
maintenance window.

**Post-read action:** Complete D0–D4, review the generated evidence manifest,
then explicitly approve or reject the destructive D5 window.

## 1. Outcome and boundary

Enlarge Discovery's 512 MiB ESP to 2 GiB by reinstalling only its two-SSD
Btrfs RAID1 system. Preserve the 4 TB `vault` HDD, restore fleet control-plane
state, and prove every critical consumer before reopening normal workloads.

This is not a zero-downtime migration. DNS, ingress, runtime-secret delivery,
registry, monitoring, and home workloads may be unavailable during a declared
window. The window length is set from measured rehearsals, not guessed in
advance.

This plan does not authorize the reinstall. It also does not combine unrelated
stateful-stack cleanup with the ESP migration. Active collision/adoption work
must reach a stable checkpoint before D4.

### Preparation progress — 2026-07-14

- D0 remains open: Kepler collision migration K1 is active and Discovery P1 is
  deliberately frozen through K5.
- D1 configuration is complete: both SSD selectors and the Btrfs peer use
  stable ATA IDs. The generated disko script hash
  `ff21f4815320662346c943b2b603ed2da587d8f08a7099f8a1f4676f76723f8c`
  contains exactly the two reviewed Kingston SSDs.
- The live preflight independently resolved those IDs to `/dev/sda` and
  `/dev/sdc`, resolved vault serial `ZTT25R4M` to `/dev/sdb`, matched the vault
  UUID, and confirmed Docker still resides on the destructive RAID.
- `just dry discovery` passed. Orion's HTTP binary-cache endpoint timed out
  during evaluation, but Nix disabled that substituter and completed the dry
  build; Orion's SSH builder remained functional. Cache health must be restored
  before D4 so the maintenance window does not depend on fallback behavior.

## 2. Corrected live-state model

The 2026-07-14 inventory established:

| Device/state | Live identity | Migration treatment |
|---|---|---|
| Primary SSD | Kingston 480 GB, serial `AA000000000000000105`; current ESP + one Btrfs RAID1 member | Destructive target |
| Mirror SSD | Kingston 480 GB, serial `AA000000000000000098`; second Btrfs RAID1 member | Destructive target |
| Vault HDD | Seagate 4 TB, serial `ZTT25R4M`; ext4 UUID `d026033d-158d-49ca-9ff9-dd2d5c8a21dc` | Must remain outside disko and mount unchanged |
| Docker root | `/var/lib/docker`, about 107 GiB | On destructive RAID; cold-mirror before reinstall, restore to fresh RAID before start |
| Mutable home | `/home/erik`, about 130 GiB | On destructive RAID; back up and selectively restore |
| HAOS disk | `vault` HDD | Survives; verify detached clone before migration |
| OpenBao raft | host state on destructive RAID | Fresh snapshot and isolated restore proof required |
| SSH/Tailscale/sops identity | host state on destructive RAID | Stage into installer and compare fingerprints after boot |

The former premise that Docker data survives because the vault disk survives is
false. The vault HDD is recovery staging, not the permanent Docker root: moving
critical containers from RAID1 to one HDD would reduce availability and storage
performance after the migration.

Current baseline: OpenBao is initialized and unsealed; DNS and SWAG probes pass;
HAOS is running from the vault HDD. Existing failed units are the expected
Telstar capacity retry and a homelab-IaC drift failure, which must be explained
or cleared in the final baseline rather than silently accepted.

## 3. Recovery order and dependency graph

Recovery is deliberately bottom-up:

1. Network, stable host identity, vault HDD mount.
2. sops bootstrap secrets.
3. OpenBao raft restore and unseal.
4. Vault-agent runtime-secret renders.
5. Docker and the shared PostgreSQL/Redis layer.
6. AdGuard DNS.
7. SWAG/Cloudflare ingress and NetBird/PocketID.
8. Harbor and k3s registry consumers.
9. Monitoring and alerting.
10. HAOS, media, AI, tools, and remaining household workloads.

No higher layer is used to validate a lower layer. For example, OpenBao recovery
is checked through its local API before a Vault-backed Compose service starts;
DNS is queried directly before SWAG hostnames are used.

## 4. D0 — freeze competing state changes

Before rehearsals:

- finish or explicitly checkpoint the active Kepler/Discovery stateful-stack
  work; record its exact repository revisions and active deployment branches;
- freeze Compose schema, volume renames, OpenBao policy changes, DNS changes,
  Harbor upgrades, and HAOS disk changes;
- capture the read-only migration inventory and service exposure baseline;
- classify every active bind mount, named volume, and anonymous volume as
  preserve, restore, or rebuildable;
- require a clean ownership manifest. Zero links, zero bytes, or an old Compose
  label never proves disposability.

Any change to disk identity, Docker root, volume ownership, secrets schema, or
the Compose revision invalidates later evidence.

## 5. D1 — make the destructive graph fail closed

Replace volatile `/dev/sdX` selectors with the two reviewed SSD stable IDs.
Generate a Discovery-only disko script and assert:

- both Kingston SSD serials are present;
- the Seagate vault serial, its UUID, and `/dev/sdb` are absent from every
  destructive command;
- the new ESP is exactly 2 GiB;
- Btrfs data and metadata profiles remain RAID1;
- no generated hardware scan can overwrite the reviewed disk graph.

Build the full Discovery closure on Orion or Kepler with controller local jobs
disabled. The laptop may orchestrate but must not build.

## 6. D2 — create and rehearse a cold Docker recovery mirror

Docker remains on RAID1 in normal operation. Before the reinstall, create a
verified cold mirror on the surviving vault HDD and prove that it can seed a
fresh Docker root. This is a recovery artifact, not a live data-root change.

1. Create a dedicated vault-disk Docker directory with root-only ownership.
2. Copy the live Docker tree while workloads run.
3. Enter a short write freeze: stop schedulers, Compose units, Docker, and any
   direct database writers.
4. Perform a final preserving sync, record source/destination byte counts and a
   representative metadata/hash manifest.
5. Restore that mirror to a scratch filesystem on Orion using the same copy
   flags that will seed Discovery's fresh `/var/lib/docker`.
6. Start an isolated Docker daemon against the scratch root and verify expected
   images, volumes, networks, metadata, and representative containers without
   registering production identities or binding production ports.
7. Measure both final-sync and restore durations; include them in the window.
8. Restart production Docker against its unchanged RAID root and run the normal
   critical probes.

During D5, restore the cold mirror onto the fresh RAID root before starting the
production Docker daemon. Keep the vault mirror read-only until the retention
review. Off-host application-level backups remain mandatory: neither RAID nor a
second local copy is a backup.

## 7. D3 — isolated rehearsals on other hosts

Each rehearsal uses copied state and isolated ports/networks. It must not share
production DNS names, tailnet identity, Cloudflare tunnels, NetBird management
identity, or writable backup repositories.

### 7.1 DNS and AdGuard

- Restore AdGuard configuration and work data into an isolated container on
  Orion.
- Query local overrides, blocked domains, upstream recursion, and DNSSEC using
  a non-production port.
- Prove a temporary LAN fallback resolver on Kepler can answer the minimal
  records needed during recovery. Activating it in DHCP is optional for the
  maintenance window, but its command and rollback must be rehearsed through
  the network source-of-truth.

### 7.2 OpenBao

- Start a disposable NixOS VM on Orion with no production listener.
- Restore the newest off-host raft snapshot into a fresh cluster using the
  documented old-key procedure.
- Verify initialized/unsealed state, representative KV paths from each consumer
  class, AppRole authentication, and a read-only policy denial.
- Record snapshot ID, age, checksum, source repository, duration, and commands.
- Destroy the disposable copy after evidence capture; never promote it.

### 7.3 PostgreSQL and Redis-backed services

- Restore fresh PostgreSQL dumps into an isolated PostgreSQL instance on Orion.
- Verify roles, extensions, schema counts, and representative rows for LiteLLM,
  Langfuse, NetBird, and any other discovered databases.
- Test Redis only where it contains non-rebuildable state; otherwise prove the
  declared cold-start behavior.

### 7.4 NetBird and PocketID

- Restore copied state with external listeners and outbound tunnel registration
  disabled.
- Verify PocketID data opens, NetBird management reads its database, and the
  expected users/groups/peers exist.
- Do not run two production management planes or reuse production relay auth in
  the rehearsal.

### 7.5 Harbor

- Rebuild Harbor from declared configuration against copied/restored state.
- Authenticate, pull a known image, push a disposable image, and verify registry
  garbage-collection metadata remains coherent.
- Prove Kepler k3s can fall back to public registries while Harbor is offline;
  do not make the test depend on Discovery DNS.

### 7.6 SWAG and Cloudflare

- Restore copied SWAG configuration and validate nginx plus certificate files
  without binding production ports.
- Probe representative internal routes against explicit addresses/Host headers.
- Do not start a second production Cloudflare tunnel with the same credentials.

### 7.7 HAOS

- Run an integrity check against a read-only clone of the QCOW2.
- Boot the clone on Orion with networking disconnected; reach the login/health
  boundary and shut it down cleanly.
- Never attach the live QCOW2 to two hypervisors.

### 7.8 Home and miscellaneous state

- Create an encrypted snapshot of mutable home state after the freeze.
- Selectively restore and hash: sops age key, SSH material, servarr runtime
  config, SWAG certificate/config, PocketID bind data, a normal document, and a
  large file.
- Prove Git-only repositories can be recreated independently; do not bulk
  restore generated or stale clones over fresh declarative state.

## 8. D4 — final evidence and approval manifest

Immediately before the maintenance window, produce one immutable manifest:

- exact repository revisions and deployment branches;
- SSD and vault stable identities plus generated disko-script hash;
- closure path/hash and remote builder identity;
- Docker source/mirror/restore roots, validation timestamp, and measured copy
  durations;
- OpenBao snapshot IDs from local, Kepler, and Voyager repositories;
- PostgreSQL dump identifiers and isolated restore results;
- per-service rehearsal result and measured duration;
- home snapshot ID and selective restore hashes;
- SSH fingerprint, Tailscale-state hash, sops staging proof;
- expected stopped services, known baseline failures, abort thresholds, and
  estimated maintenance-window duration;
- exact post-install restore/start order.

Evidence older than 24 hours for databases/OpenBao/home, or older than 90 days
for a full recovery rehearsal, blocks approval. Any manifest drift after
approval blocks execution and requires regeneration.

## 9. D5 — controlled maintenance window

### Before the wipe

1. Announce the window and confirm an independent administration path.
2. Start the temporary DNS fallback if selected.
3. Stop automation first: upgrades, Renovate, backup schedulers, Ofelia,
   downloads, media writers, and IaC drift/apply jobs.
4. Quiesce application writers, then PostgreSQL/Redis consumers.
5. Take fresh database dumps, OpenBao raft snapshot, and encrypted home backup;
   run the required selective restores.
6. Stop remaining Compose units, HAOS, Docker, OpenBao, and libvirtd cleanly.
7. Verify the vault HDD is healthy and unmounted from the destructive graph.
8. Re-run live disk identity, graph, closure, and manifest gates.

Only then print the destructive boundary and run the reviewed installer.

### After installation

1. Boot the new RAID root and verify the 2 GiB ESP, RAID1 profile, networking,
   SSH identity, Tailscale identity, and sops decryption. Only expected
   pre-restore units may be inactive; no unit may be unexpectedly failed.
2. Mount the vault HDD by UUID and verify it before Docker/libvirtd may start.
3. Restore mutable home paths selectively; run Home Manager afterward so
   declarative links win.
4. Restore OpenBao raft, unseal with the original key, and verify local KV/API.
5. Start Vault-agent and verify every required runtime-secret render exists.
6. With Docker stopped, restore the cold mirror to the fresh RAID
   `/var/lib/docker`; verify ownership, byte counts, metadata, and Docker's
   configured root.
7. Start Docker, PostgreSQL/Redis, then AdGuard. Run direct database and DNS
   probes.
8. Start SWAG/Cloudflare and NetBird/PocketID; run ingress and overlay probes.
9. Start Harbor and verify workstation plus k3s pull paths.
10. Start monitoring/alerting and confirm an end-to-end test alert.
11. Start HAOS and remaining household workloads in dependency groups.
12. Reboot once more and repeat critical probes before ending the window.

## 10. Abort and recovery boundaries

Before the wipe, rollback each rehearsal/cold-mirror step independently. After the
wipe, recovery is forward-only: reinstall the same reviewed system and restore
from the evidence bundle.

Abort before destruction on any of:

- vault disk present in the destructive graph or missing by stable identity;
- Docker cold mirror or scratch restore proof missing;
- stale/unverified OpenBao snapshot or database dump;
- failed selective restore;
- unavailable remote builder, installer path, sops key, or console access;
- unexplained failed critical service or storage error;
- active writer or competing migration.

Keep the old Docker tree, encrypted home snapshot, all database dumps, and
OpenBao snapshots until a post-migration retention review. Do not delete them as
part of the maintenance window.

## 11. Completion criteria

Discovery migration is complete only when:

- ESP is 2 GiB and Btrfs data/metadata are RAID1 on the reviewed SSDs;
- vault HDD identity and filesystem are unchanged;
- Docker uses the fresh RAID data-root and expected containers/volumes are
  present; the vault mirror remains a retained recovery artifact;
- OpenBao is initialized, unsealed, backed up again, and all secret consumers
  have refreshed;
- DNS, ingress, NetBird/PocketID, Harbor, PostgreSQL, monitoring, HAOS, and
  representative media/AI workloads pass their rehearsal-equivalent probes;
- no unexplained failed system or user units remain;
- the second reboot passes the same critical checks;
- the maintenance evidence and retention ledger are committed to the proposal.
