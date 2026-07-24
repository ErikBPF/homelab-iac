# Stateful stack release hardening — execution plan

**Status:** In progress — P0, Kepler recovery, Discovery P1 SWAG adoption, P2
AdGuard in-place adoption, P3 secondary-DNS outage proof, and P4 full AdGuard
Terraform ownership, P5 canonical-volume migration, and P6 kindle-dash
protected automatic releases are complete. P7 is active.

## 1. Purpose and authority

This is the operator execution plan for
[`2026-07-13-stateful-stack-release-hardening.md`](2026-07-13-stateful-stack-release-hardening.md).
It is written for a fresh operator continuing the rollout without chat history.
The proposal's locked ownership boundaries, safety constraints, verification
contracts, and acceptance criteria remain authoritative. This document merges
the urgent Kepler collision recovery into the rollout order. The detailed
Kepler behavior and test contract remain normative TDD artifacts. If an
operational document conflicts with a `just` recipe, the recipe wins and the
document must be corrected.

| Repository | Ownership |
|---|---|
| `desktop-nixos` | Kepler and Discovery host orchestration, fixed migration workflows, release agent, monitoring |
| `servarr` | Kepler and Discovery Compose stacks, secret contracts, physical volumes, immutable workload pins |
| `homelab-iac` | AdGuard and Cloudflare Terraform, wired-LAN plans and applies |
| `kindle-dash` | Tests, protected-main releases, SemVer, signing, SBOM and provenance |

Leaf repositories land first. Consumers and host orchestration follow only
after the leaf commit is published and pinned.

Discovery SecretSpec rollout is now tracked independently in Servarr's
[`machines/discovery/secretspec-inventory.md`](https://github.com/ErikBPF/servarr/blob/097280976683ab82e0dbe53bd60e7b8b07d5613a/machines/discovery/secretspec-inventory.md).
This execution plan retains K0 and P1 evidence only; its P2–P9 phases do not
authorize or order additional SecretSpec profiles.

The merged order is `P0 → K0–K5 → P1 → P2 read-only → P3 → P2 mutation → P4–P9`.
P3 is advanced only as the secondary-DNS safety interlock required by P2; its
behavior and test contract define the boundary. Kepler and Discovery live mutations
are never concurrent. Discovery remains available as the LiteLLM gateway while
Kepler is recovered; after K5, Kepler remains stable while Discovery resumes.

## 2. Current state

### P0 — complete

- Servarr `98ecafb` records migration debt and rejects new implicit or anonymous
  state volumes.
- Desktop `50454f9`, `6217215`, and `061a1cc` provide ledger-gated inventory,
  snapshot, archive, restore, compare, smoke, rollback-evidence, and orphan
  tooling.
- The disposable fixture passed using servarr `312fa76` and digest
  `sha256:ce148c3794d2dfcb63eaeed55c516324e800349f8cd57e49ec0eb312fe75f01d`.
- Read-only snapshot
  `/home/.snapshots/stateful-stack-p0-fixture-20260713` has UUID
  `342edcd9-15a8-0448-8822-3347328d0ff2`.
- Archive checksum/read and restored byte, ownership, mode, ACL, and xattr
  comparisons passed. All fixture resources remain retained.
- P0 completion evidence is in desktop `5a24439`.

### P1 — complete

- Servarr `b676063` retains immutable SWAG and `swag-init` pins, publishes the
  complete Discovery networking SecretSpec contract, removes the tracked
  runtime credential, and recreates it atomically with mode `0600` and owner
  `1000:1000`. Runtime consumption remains git-pull based; this flake has no
  Servarr input.
- The original transition manifest
  `426fa097cd4b6ce0e12609e25f64732dac0f1dacfb4dda8f1a3563f3cca854e4`
  stopped before any container lifecycle phase when its rendered-Compose
  contract was found incorrect, after the repository reset removed the tracked
  credential path. Its no-clobber journal remains preserved as superseded
  evidence.
- The operator approved amendment manifest
  `94781f280a9a321d55b8ed7ad598b2df4202725ce80893440eadfe4b977a62fd`,
  bound to observation
  `2851163419f0f18ee928e6d11ff54d5e4723d410e5bf164506eeb3548ae1663e`,
  for exactly `swag-init` and `swag` while preserving the superseded journal.
- The resumable amendment recreated only those two containers. It verified the
  corrected value-free Compose render, exact project/owner/images/bind,
  credential metadata without reading its value, SWAG health, the immutable
  standard Certbot hook set, nginx, certificate/DNS-01, ingress, and Kindle PNG.
  No volume, snapshot, backup, or bind state was deleted.
- The final result is `status: passed`, with runtime SHA-256
  `e695dbefc12260c86a0ae77dbeb6f22d38ea3ee717a17a815c04e0e25d5309a6`.
  Re-executing the same approved amendment returned the identical result and
  performed no container recreation, proving resumability after completion.
- Desktop `e167be6` is the final executor/gate revision. Discovery was observed
  transitioning down and up through the fixed reboot recipe. Tailscale briefly
  waited on DNS during the first boot probe, then repeated host verification
  passed with no failed units and healthy Tailscale, Syncthing, Home Manager,
  and SOPS checks.
- The approved amendment binding remained valid after reboot. Completed-state
  validation returned the identical `status: passed`, runtime SHA-256, render
  SHA-256, and Kindle PNG SHA-256 without recreating either container. P1 is
  closed; every journal and superseded record remains retained.
- A fixture-tested, offline preflight now exact-binds the two container IDs,
  Compose labels and working directory, immutable image references and image
  IDs, `/config` binds, Servarr commit and rendered-Compose hash, evidence
  paths, certificate metadata, and the canonical inventory SHA-256. It rejects
  unknown resources, evidence collisions, value-bearing fields, and changed
  inventory. `just discovery-swag-preflight` creates the read-only envelope and
  `just discovery-swag-result` revalidates its exact binding. The fixed
  `discovery-swag-inventory` entrypoint captures only read-only, value-free
  runtime identity, and `just discovery-swag-inventory` validates it before
  saving it. The execute entrypoint accepts an explicit approved manifest hash
  and value-free authorization envelope, then captures and verifies a fresh
  inventory before creating evidence or running any stop, snapshot, archive,
  or Compose command. The manifest hash also binds a versioned, exact ordered
  action contract and rollback implementation identity. Every created evidence
  path is in one no-clobber set. Immediately before stopping SWAG, both
  containers are re-inspected against the approved identities and the captured
  full SWAG ID is used. Drift fails closed. The rollback entrypoint validates
  the retained authorization, inventory, manifest hash, exact ledger schema and
  paths, archive checksum target/content, and retained snapshot, then runs a
  fixed Compose recreation; it never evaluates ledger command text.
  Workflow semantic changes must alter the ordered contract or bump its version,
  invalidating prior authorization hashes. Snapshot or archive failure after
  the exact stop retains partial evidence, leaves SWAG stopped, and reports the
  fixed hash-bound pre-adoption recovery entrypoint for explicit operator
  review. That narrow path verifies the retained authorization and exact ledger,
  re-inspects both approved container identities with SWAG stopped, and starts
  only the captured legacy SWAG ID. It runs no Compose command and does not
  weaken the stricter archive/snapshot requirements of post-recreation rollback.
  Certificate drift is fail-closed against the four SANs declared by Servarr:
  `*.homelab.pastelariadev.com`, `*.k8s.pastelariadev.com`,
  `ha.pastelariadev.com`, and `k8s.pastelariadev.com`; fixture coverage uses
  the sorted shape emitted by the read-only collector.
  The historical adoption workflow remains retained as evidence; the completed
  amendment is the authoritative P1 adoption result.

### K0 — complete

At K0 completion:

- Kepler collision behavior and fixture-test contract are approved.
- GitLab, Airflow, and Restate declarations are retired; their exact live
  resources had not yet been deleted. All three were disposable homelab tests.
- SecretSpec `0.13.0` is available from the pinned nixpkgs. It is a declaration
  and preflight layer, not a replacement for SOPS or Vault Agent.
- No Kepler runtime mutation, destructive wipe, backup purge, snapshot, or
  quarantine had run.
- Servarr `1805e1d` published the value-free Kepler SecretSpec contract.
- Twenty-one planner fixtures, Kepler dry-build, and full flake verification
  passed without changing production secret resolution or runtime startup.
- K1 was blocked pending a fresh read-only live inventory and exact approval
  manifest.

### K1–K4 — operational recovery complete with recorded deviation

- Servarr `6e215e9` removes F5-TTS from the desired Kepler stack, environment
  contract, local-image provenance, model provenance, validation, and operator
  recipes.
- Desktop `4fdae50` pins that Servarr revision, removes the F5-TTS host port and
  model-path expectations, and adds value-free dry-run planners for retained
  PostgreSQL evidence, disposable Redis reset planning, and exact retirement/disposition.
- The retirement planner validates the live inventory's internal SHA-256,
  rejects shared images and unknown resources, exact-allowlists Restate, binds nested
  evidence, and emits no execute mode or destructive command.
- Exact retirement manifests were rendered from fresh value-free inventories
  and explicitly approved by hash. After evidence-gated execution repeatedly
  stopped on stale runtime facts, the operator explicitly authorized the
  bounded force path and full declared-stack reset because the retired payloads
  were disposable homelab tests and downtime was acceptable.
- The force path removed only the exact Airflow database, approved scratch
  containers, GitLab/F5 bind paths, and exact GitLab/F5 images. It did not run a
  broad prune, delete a parent dataset, delete snapshots/backups, or expose
  secret values.
- The declared-stack reset removed exactly the 12 inventory-bound containers
  plus disposable Redis volumes `homelab_redis_data` and `infra_redis_data`.
  Persistent PostgreSQL, Qdrant, MinIO, and model bind paths were retained.
- `infra`, `ai-serving`, and `docs-search` were recreated declaratively. A fresh
  inventory found all 12 expected containers running under their desired
  Compose projects and reproduced inventory SHA-256
  `74c70f4ab0c025bac510734f31d0b351df4a28f431bf68ae57dbae0ee42f184a`.
- This was an approved operational deviation from K3 snapshot/restore proof and
  K4 collision-by-collision quarantine. Those unexecuted protections must not
  be claimed as evidence or retroactively marked complete.

### K5 — superseded by AI-serving retirement

- Kepler rebooted once through the documented workflow and returned after an
  extended boot interval.
- Post-reboot host verification passed: zero failed units, Tailscale and
  Syncthing active, Home Manager successful, SOPS age key present, and staging
  cleanup complete.
- All 12 expected containers are running in `infra`, `ai-serving`, and
  `docs-search`. Ports `8085`, `8087`, `9000`, `10200`, and `8765` respond; the
  NVIDIA RTX 3070 and embedding workload are visible on the GPU.
- `slm-bge-m3` reached healthy. The reranker remained in normal cold-start when
  the operator waived further waiting; this is recorded as incomplete health
  evidence, not a failure.
- The final read-only post-recovery audit converged with all 12 declared
  containers classified as `none`, no retired resources selected, no halt
  reasons, inventory SHA-256
  `74c70f4ab0c025bac510734f31d0b351df4a28f431bf68ae57dbae0ee42f184a`,
  and manifest SHA-256
  `b1a43fae85f277b682fcde3c3daacece70e65bf0447dab4df3788ce0329c0331`.
- Discovery LiteLLM route checks passed through the gateway for `bge-m3`,
  `bge-reranker-v2-m3`, `whisper-pt-br`, and the offline
  `tts-pt-br-piper` fallback. The primary Edge TTS route `tts-pt-br` returned
  HTTP 500 on three bounded attempts (approximately 31–38 seconds each).
  At that checkpoint K5 was blocked on that route and Discovery P1 remained
  frozen. No service restart or runtime configuration change was attempted;
  the operator-approved retirement deviation below superseded this route gate.
- On 2026-07-14 the operator declared the entire Kepler AI-serving stack and
  model cache disposable and reproducible. Servarr `8edab1a` removes all seven
  services. Desktop desired state now contains only `infra` and `docs-search`,
  closes the retired ports, and removes the model-cache tmpfiles and NVIDIA
  container runtime. The exact-ID retirement removed the seven containers,
  seven local images, and `/fast/ai-models`, then returned idempotent status
  `already-retired` with manifest SHA-256
  `de8ce750ba6a1316ffca0b354615badfab994ec7a19fdd0de67ac2cd35660c3f`.
  After reboot, only the four `infra` containers and `docs-search` remain;
  ports `8002`, `8003`, `8085`, `8087`, `9000`, `9835`, and `10200` are closed.
  The final read-only audit converged with five `none` actions, inventory
  SHA-256 `71e89e49eb36a2eef72dba78fa84a7b17edb005fb965b064a2afd1917cb8c1b8`,
  and manifest SHA-256
  `508eda98acacfadf8ba0368321f1c433352f6a74e60b64669e3810951077ca5c`.
  No network, volume, snapshot, dataset, or broad-prune cleanup ran.
  Discovery/HA routes are now consumer cleanup, not a K5 health gate.

### Known later gates

- P3: vanguard CoreDNS works over Tailscale, but LAN DHCP advertises only the
  UDM. Generic LAN clients lack a secondary fleet resolver.
- P4: `gmichels/adguard` `v1.7.0` previously failed an update with DHCP
  disabled. A disposable lifecycle proof or provider fix is required. The IaC
  repository also contains unrelated dirty work that must be isolated.
- P5: complete 2026-07-19. The approved empty collision
  `discovery_adguard_work` was deleted after revalidating zero references,
  entries, and bytes. Servarr commit
  `eaa1f4f79305009356bcba3f87560f09d2c1fdd5` declares
  `discovery-adguard-work`. Migration ledger, read-only Btrfs snapshot, and
  checksum-verified 3.25 GB archive were retained; archive restore matched
  byte/metadata state before recreation. Pre- and post-reboot probes proved the
  canonical mount, healthy zero-restart containers, external and rewrite DNS,
  exporter metrics, and readable archive. Legacy `networking_adguard_work`
  remains unreferenced and retained for rollback. Discovery returned shortly
  after the reboot recipe's 240-second timeout; subsequent host verification
  showed no failed units and all P5 probes passed.
- P6: kindle-dash `main` is unprotected; releases are tag-only and unsigned;
  no scoped GitHub App credentials exist for verified servarr pin PRs.

## 3. Non-negotiable rules

1. Execute `P0 → K0–K5 → P1–P9` in order. Later phases may be inspected, not
   mutated, before their predecessor completes.
2. Re-read repository instructions/runbooks and re-inspect live state before
   every slice.
3. Preserve unrelated dirty work. Stage only active-slice files.
4. Before workload mutation, persist commit, container/project/owner, image
   tag/digest, physical storage/mount, size/ownership, backup identifiers,
   rollback command, and downtime estimate.
5. Adopt existing state in place before canonical copying.
6. Never delete a container, volume, snapshot, backup, or remote state without
   current-turn approval naming that resource.
7. Keep legacy containers and volumes through smoke tests and one reboot of the
   affected host. Databases also require a successful backup cycle before state
   cleanup. GitLab and Airflow are the only scoped immediate-wipe exception.
8. Mutate Kepler or Discovery only through documented `just` recipes or fixed
   approved systemd workflows. Never edit remote files.
9. Apply Terraform only from wired LAN, using an inspected saved plan and live
   post-apply probes. Stop on unexplained drift.
10. Registry images require immutable digests. Local builds require image ID,
    source commit, and build inputs; model artifacts require independent
    checksum/version evidence. Never deploy `latest`.
11. Stop on checksum mismatch, missing backup, ownership ambiguity, unexplained
    drift, or rollback failure.
12. Never weaken tests, health gates, branch protection, signature validation,
    or security boundaries.

## 4. Per-slice contract

1. State assumptions, repositories, risk, downtime, rollback, and verification.
2. Capture failing tests or observable pre-change evidence where practical.
3. Make the smallest owner-local change.
4. Run repository-local format, lint, tests, and config evaluation.
5. Commit/publish the leaf repository, then pin it in the consumer.
6. Write the complete ledger before workload mutation.
7. Stop only affected services; snapshot and checksum/archive state.
8. Prove archive read/restore/compare before irreversible change. Kepler uses
   the explicitly scoped logical-backup restore tests plus ZFS/independent
   mount coverage in K1/K3 instead of blanket archives of Qdrant and MinIO.
9. Mutate through the approved recipe or systemd workflow.
10. Run hard smoke gates and inspect logs/metrics.
11. Verify rollback evidence before removing old protection.
12. Record exact commits, digests, volumes, snapshots, plans, probes, and risks.

Desktop final gates:

```bash
just lint
just fmt-check
just dry discovery
just dry kepler
```

Run `just check` for shared/fleet behavior and `just docs-check` for docs.

## 5. Ordered phase plan

### P0 — audit and safety tooling — complete

Delivered: live owner/state inventory; state impact classification; servarr
explicit-volume policy and fixtures; ledger/snapshot/archive/restore/compare/
smoke/rollback/orphan helpers; retained disposable live proof; exact evidence.
No fixture cleanup is authorized.

### K0 — SecretSpec contract and fixture tests — complete

1. Package the pinned SecretSpec version declaratively; do not install it with
   an unpinned curl script.
2. Add one Kepler manifest with stack profiles for `infra`, `ai-serving`, and
   `docs-search`. Do not retain GitLab, Airflow, or Restate declarations.
3. Treat SecretSpec as the mandatory contract and value-free preflight layer.
   Keep SOPS for host/build/bootstrap secrets and Vault Agent for long-running
   runtime resolution.
4. Add drift tests proving Compose-required variables, Vault Agent templates,
   SOPS key names, `.env.example`, and SecretSpec declarations agree without
   reading or printing values.
5. Add fixture tests for classification, allowlists, immutable identities,
   mount coverage, manifest hashing, ordering, idempotence, and every failure
   stop in the Kepler test contract.
6. Produce a draft Discovery inventory only. Complete each Discovery stack
   profile immediately before its phase; `networking` becomes a P1 gate.

### K1 — Kepler inventory, backups, and approval manifest

Current progress: the deterministic validators and dry-run planners are
published. No remote execution path exists yet, and no K1 mutation has run.

1. Re-inspect every rootless-Podman container, Compose label, owner, state,
   image, mount, network, secret declaration, backup, snapshot, and collision.
2. Classify only exact GitLab/Airflow/Restate resources as `retired-wipe`; halt
   on running, unlabeled, foreign, unknown, or mount-mismatched
   collisions. The reviewed stopped legacy `homelab` infra project may be
   adopted only with exact provenance as defined by the behavior contract.
3. Pin registry images by digest. Record immutable local image and model
   identities. Halt any slice whose desired identity is not reproducible.
4. Quiesce shared PostgreSQL and create restore-tested logical backups of all
   retained databases before planning the Airflow database drop.
5. Inventory current GitLab/Airflow secret declarations and externally valid
   credentials. Historical copies, mixed-backup sanitation, and Git-history
   rewriting are out of scope because the stacks were disposable homelab tests.
6. Render a value-free, immutable action manifest with exact resources,
   commands, rollback boundaries, and SHA-256. Execution requires user approval
   naming the manifest hash and resources; any live drift invalidates it.
   Running collisions require a separate exact quiesce manifest and a fresh
   inventory before the K1 manifest can become ready.

### K2 — exact GitLab/Airflow retirement

1. Re-inventory and verify the approved K1 manifest hash before mutation.
2. Drop only the Airflow database, remove only the approved GitLab/Airflow
   containers, volumes, bind paths, service-specific images/caches, current
   SecretSpec/SOPS/OpenBao/env declarations and values, and approved non-Git
   current secret artifacts.
3. Revoke every externally valid retired credential before current artifact deletion.
4. Never broadly prune, destroy a parent dataset, rewrite Git history, or delete
   an unlisted backup or unlisted resource.
5. Verify shared PostgreSQL and all retained services before continuing.

### K3 — retained-state protection

1. Stop dependents; checkpoint PostgreSQL; confirm Qdrant and MinIO writes are
   idle. Redis is a disposable cache and has no backup/restore requirement.
2. Restore-test logical PostgreSQL backups. Bind the exact stopped legacy
   `redis` container and exact `homelab_redis_data` volume in the approval
   manifest. Any running container, foreign ownership, additional reference,
   or inventory drift halts before reset.
3. Create a timestamped recursive ZFS snapshot of retained state only. Every
   persistent mount outside its boundary requires an independently verified
   backup or the campaign halts.
4. Thirty days marks cleanup eligibility, not automatic deletion. Snapshot and
   backup deletion always requires later exact-resource approval.

### K4 — resumable collision recovery

Run one maintenance campaign as three resumable slices: `infra`, `ai-serving`,
then `docs-search`. Each slice has its own ledger and stop boundary.

For one stopped collision at a time, rename the legacy container to
`legacy-<name>-<timestamp>`, start the declarative replacement under the
original name, and require exact identity, labels, mounts, networks, health,
clean logs, state checks, endpoint probes, dependent smoke tests, and 15 minutes
without restart or regression. A failure stops the replacement and retains the
quarantine and snapshot. Never restore ZFS or restart legacy state
automatically. Do not delete quarantined non-retired containers in K4.

The `infra` slice is the explicit Redis exception: remove only the approved,
stopped legacy `redis` container and approved `homelab_redis_data` volume, then
let declarative `infra` recreate desired Redis. Do not rename, back up, restore,
or quarantine legacy Redis cache data. No broad container or volume deletion is
permitted, and a changed inventory invalidates the manifest.

### K5 — reboot, cross-host validation, and retention ledger

1. Reboot Kepler only through its documented workflow.
2. Repeat all stack identity, state, endpoint, dependency, and backup probes.
3. Verify Discovery LiteLLM routes against recovered Kepler backends while
   Discovery remains otherwise unchanged.
4. If Orion is online, record its Discovery LiteLLM route and Orion-to-Kepler
   Restic connectivity; Orion being offline is non-blocking and causes no Orion
   mutation.
5. Run a second read-only planner proving no collision or pending migration.
6. Retain quarantined containers, snapshots, backups, and ledgers. Generate a
   separate cleanup manifest for later named-resource approval.
7. Unfreeze Discovery P1 only after all K5 gates are green.

### P1 — SWAG in-place adoption — complete

#### P1.1 Immutable pins — complete

- SWAG:
  `lscr.io/linuxserver/swag:5.6.0-ls467@sha256:ce148c3794d2dfcb63eaeed55c516324e800349f8cd57e49ec0eb312fe75f01d`
- Init:
  `busybox:1.38@sha256:fd8d9aa63ba2f0982b5304e1ee8d3b90a210bc1ffb5314d980eb6962f1a9715d`
- Compose render, digest assertions, and state-volume tests passed.

#### P1.2 In-place adoption — complete

Executed for exactly `swag`, `swag-init` under amendment manifest SHA-256
`94781f280a9a321d55b8ed7ad598b2df4202725ce80893440eadfe4b977a62fd`:

1. Validate the approved observation, authorization, superseded journal,
   Servarr target revision, and corrected value-free Compose render.
2. Re-inspect the exact original runtime and credential rewrite source.
3. Recreate only init/SWAG through fixed Compose arguments.
4. Require exact digest/project/owner/bind, healthy state, and no restart loop.
5. Require the credential path, mode `0600`, and expected owner without reading
   or logging its value.
6. Bind the exact standard Certbot hook metadata and hashes, then run nginx,
   exact four-SAN/expiry, and Certbot DNS-01 dry-run gates.
7. Probe Grafana `200`, AdGuard `302`, and LAN Kindle `/dash.png` PNG.
8. Persist the hash-bound final runtime and validation result while retaining
   every earlier journal.

The original manifest stopped after repository reset on a rendered-Compose
contract mismatch, before container lifecycle. The amendment separately
stopped on health and hook-contract gates, preserved partial evidence, then
resumed after reviewed executor corrections. The completed amendment journal
and superseded original journal are both retained.

#### P1.3 Reboot persistence

Run `just reboot-discovery` to prove a down/up transition and generic host
health. Then re-run the already-approved amendment execute recipe with the
retained observation, authorization, and manifest hash:
`just discovery-swag-transition-amendment-execute <observation>
<authorization> <manifest-sha>`. Its completed-state path performs no
recreation and repeats the exact SWAG identity, mount, credential-metadata,
health, certificate, DNS-01, ingress, and Kindle gates. Record both results;
then close P1.

Completed: Discovery was observed down then up; generic host verification and
the exact completed-state amendment gates passed. Reboot-time device/inode
changes from the declared atomic credential writer are accepted only in the
read-only persistence validator. Path, file type, symlink state, mode, and
ownership remain exact; transition-time identity evidence remains immutable.

### P2 — AdGuard in-place adoption

Read-only preflight completed on 2026-07-15. Servarr `9969e35` pins both
images by digest and declares the existing `networking_adguard_work` volume as
external. Desktop `6dc5c0c` binds the exporter baseline to the three metric
families registered by exporter `v1.2.1`, retaining only value-free `# TYPE`
metadata. Inventory `c4c1139e…` produced stable inventory binding
`6c37a3d0…`; preflight manifest `b1517c27…` verified as binding-valid. It is
explicitly `preflight-only`, `approval_ready: false`, and authorizes no
mutation. The protected `discovery_adguard_work` collision remains untouched.

1. Refresh API/config/filter/query-log/exporter baseline.
2. Record `networking_adguard_work`, immutable digest, size, `65534:65534`
   owner, mode, and mount.
3. In servarr, declare that existing physical volume explicitly as external;
   do not copy it.
4. Prove rendered Compose still resolves to that physical volume.
5. Ledger, stop AdGuard/dependent exporter, snapshot config, archive work, and
   prove restore/compare.
6. Recreate without copy and compare LAN query, fleet rewrite, external lookup,
   blocked response, API, filters, query log, stats, rewrites, user rules, and
   exporter.
7. Verify rollback to the same physical mapping; retain state.

Completed with an operator-approved practical recovery deviation on 2026-07-16.
The exact transition completed its snapshot, archive, non-live restore/compare,
forward revision activation, exact-pair recreation, identity checks, fatal-log
scan, 15-minute stable observation, and smoke test. Its terminal
`record-rollback-evidence` bookkeeping failed with `Drift`; automatic recovery
then failed with `KeyError` and left the Servarr checkout pinned to rollback
revision `b676063e…`. The failed journal remains retained as evidence; it was not
rewritten into a pass.

Because temporary local-DNS downtime was explicitly accepted and the workload
state is already defined by the retained YAML and physical volume, recovery used
the normal documented deployment path instead of another transition manifest.
The exact rollback `.deploy-commit` pin was retired only after validating its
schema, content hash, selection, commit, and current HEAD. `just pull-servarr
discovery` then converged the host to published Servarr `9969e35`, and `just
kick-stack discovery networking` recreated the declared stack without copying
or deleting storage. Fresh value-free inventory `f63ab37f…` proves AdGuard
healthy with zero restarts, all LAN/external/rewrite/blocked DNS probes returning
`NOERROR`, protection and filtering enabled, exporter reachable with all three
required metric families, and `networking_adguard_work` still mounted with
`65534:65534` ownership and mode `0700`. The protected legacy collision remains
untouched.

### P3 — secondary fleet DNS

Desktop `3c88a30` enabled Kepler's LAN-only resolver; `5903ca0` added the
value-free live gates and vanguard tailnet identity. Fifteen remote flake checks
passed on Orion. Kepler passed direct UDP/TCP fleet and external queries before
and after reboot. Homelab-IaC `85f2737` passed CI and declared the exact Main
DHCP order `.210`, `.230`. The operator-approved wired saved plan
`8371490a…` updated only `unifi_network.this["Main"].dhcp_dns`; the post-apply
plan is clean and state inspection matches the exact pair. Desktop `a50415e`,
`19aac0d`, and `b64d290` added and hardened the isolated generic-client proof.
Its final live run obtained lease `.175` from the UDM, received the exact DHCP
option 6 order `.210`, `.230`, passed UDP/TCP fleet, wildcard, AAAA NODATA, and
external NXDOMAIN probes against both resolvers, removed its namespace, and
left the parent interface unchanged. P3 remains open only for the separately
approved AdGuard outage/restore drill. The fixture-tested drill is exposed only
through `just p3-adguard-outage-{prepare,observe,plan,execute,cleanup}`. Its
value-free manifest binds the full five-container networking-project inventory,
the pinned Discovery host key, and the client/observer/executor/callback content,
while authorizing mutation of only `adguard-exporter` and `adguard`. Execution
rejects inventory or implementation drift, requires a bounded no-RA/RDNSS proof,
caps normal-resolver failover at 10 seconds, restores the same container IDs in
at most three bounded attempts, and retains failed-run journals for diagnosis.
The first renewed outage-client observation halted before manifest generation:
the Main LAN emits an IPv6 router advertisement containing a gateway RDNSS
server, so a normal dual-stack client can bypass the approved DHCPv4 resolver
order. P3 remains blocked until that RDNSS path is made declaratively consistent
or explicitly removed and a renewed generic-client observation passes.
Homelab-IaC `4819834` then tested the narrow provider-supported candidate
`dhcp_v6_dns_auto=false` with no manual IPv6 DNS addresses. Approved saved plan
`9ee93dfb…` changed only that Main-network field and reached a clean post-apply
plan, but a renewed client still received RA, prefix, default route, and gateway
RDNSS. The experiment was reverted in `ef3956e`; approved rollback
`83a42ead…` restored `false→true`, reached zero diff, reproduced the baseline RA
and RDNSS, and passed namespace/parent cleanup. Disabling RA is not an approved
shortcut because it would remove client IPv6. A subsequent read-only generic
client proved that the existing gateway RDNSS already matches `.210` and `.230`
for fleet A, fleet AAAA/NODATA, external A/AAAA, reserved NXDOMAIN, and blocked
responses over direct queries. The drill harness now treats that exact observed
gateway as an approval-bound third resolver, places it first in the namespace
resolver order, and requires nonce-derived UDP/TCP equivalence before, during,
and after the outage. No WAN/USG import is required; independence remains to be
proved only by the separately approved outage. Approved manifest `4b394b17…`
then stopped only the exact `adguard-exporter` and `adguard` container IDs. The
normal-resolver matrix passed, but the complete secondary matrix exceeded the
strict 10,000 ms deadline at 10,459 ms, so the retained run failed closed. The
recovery path restarted the same IDs and proved AdGuard healthy, but its
five-second exporter readiness window expired and the artifact conservatively
recorded recovery failure. Immediately afterward, the value-free exporter
diagnostic found all three required metric families and a complete fresh
observation passed RA, routes, every UDP/TCP resolver matrix, and exact
container identity. This proves the services were restored; it does not
retroactively pass the failed drill. P3 remains blocked while the harness gains
deterministic parallel outage probes and a separately bounded exporter warm-up,
after which observation, manifest, and exact approval must all be renewed.
Commit `5a0a836` added those corrections and produced renewed approved manifest
`4caa2fda…`. Its exact-ID outage reached the parallel matrix within 4,523 ms,
but retained worker row counts `6,6,6,5,6,6`: the RDNSS/TCP worker received an
unusable parsed response and a Bash conditional suppressed `errexit`, allowing
empty fields to reach an integer comparison. The run therefore failed closed
with only a partial evidence hash; it is a harness failure, not evidence of DNS
contention or a passed outage. Recovery again restarted the exact IDs and found
AdGuard healthy, but the exporter probe selected its address by concatenating
all attached-network values and exhausted its readiness window. Immediately
afterward, the declarative value-free diagnostic again reported all three
required exporter families and the complete observation passed. Services are
restored; P3 remains blocked until worker validation is explicitly fail-closed
and exporter readiness selects the single bound `homelab-net` address, followed
by another renewed observation, manifest, and exact approval.
Commit `9d7b08c` made both corrections and renewed approved manifest
`ea017b56…`. The third exact-ID attempt failed closed at 5,413/10,000 ms with
worker row counts `6,6,6,1,6,6`: both normal-system workers, both Kepler
workers, and the RDNSS/UDP worker completed, while RDNSS/TCP stopped after its
first validated row. The hardened parser emitted no false success and retained
only the partial hash. This is now evidence that the gateway RDNSS TCP path does
not satisfy the full outage contract, rather than another arithmetic/parser
failure. Recovery restarted the same IDs; its artifact again conservatively
timed out exporter readiness, while the immediate declarative diagnostic
reported all three families and the complete post-restore observation passed.
The three-attempt cap is exhausted. No further AdGuard outage may run until a
new RDNSS design or an explicitly amended behavior contract is reviewed.
The operator then explicitly accepted brief local DNS-provider unavailability
during the outage because router redundancy preserves Internet access. P3 v4
therefore narrows the live availability gate to the four policy-bearing paths:
the generic client's system resolver over UDP/TCP and direct Kepler over
UDP/TCP, all using one fresh nonce and completing the full 24-row fleet,
external, NXDOMAIN, and filtering matrix within 10,000 ms. Gateway RDNSS
UDP/TCP remains a concurrent bounded diagnostic during the outage, with
separate partial/full evidence, but remains mandatory before the stop and after
exact-ID restoration. This amendment resets the attempt cap only after its
behavior, test contract, implementation, fixtures, and v4 manifest are
committed and freshly verified; no v3 approval may be reused.
The first approved v4 manifest `43899fa6…` proved the amended outage core:
all 24 required system/Kepler rows completed in 1,560/10,000 ms, while the
gateway RDNSS diagnostic retained an allowed partial 9-row result. The original
outage result was successful, but recovery stopped before post-restore checks
because the unprivileged readiness probe could not reach the rootful exporter
network. The exact IDs were restarted; immediately afterward the deployed
privileged value-free diagnostic reported all three required metric families
and a complete fresh observation passed, proving restoration without
retroactively passing the recovery artifact. The correction replaces the
unprivileged container-IP probe with the declarative privileged helper, binds
that helper's implementation SHA-256, and keeps exact-ID identity verification
as the subsequent recovery gate. This was v4 attempt 1; at most two renewed
attempts remain after the helper is deployed and freshly bound.
Commit `d18edea` deployed the source-hash-bound privileged helper and renewed
manifest `326cee98…`. V4 attempt 2 again proved all 24 core rows in
1,561/10,000 ms with an allowed partial gateway diagnostic. The pre-stop helper
identity check passed, but the exact helper remained non-ready through its
30-second warm-up; the identical official diagnostic and a full observation
passed immediately afterward. Attempts 1 and 2 therefore place exporter
stabilization just beyond the artificial 30-second boundary. The final bounded
correction gives helper readiness 60 seconds inside one 120-second recovery
ceiling, leaving time for identity and full post-restore checks without
extending the DNS outage: AdGuard is already healthy during exporter warm-up.
This consumed v4 attempt 2. Exactly one renewed v4 attempt remains; a failure
there stops P3 pending another reviewed contract.
Commit `8eb1212` extended only the bounded validation windows and produced
approved manifest `d5cf3b59…`. The final v4 attempt passed: all 24 required
system/Kepler rows completed in 1,639/10,000 ms; gateway RDNSS retained an
allowed partial 7-row diagnostic; the same container IDs restored on recovery
attempt 1; and 37 post-restore evidence rows completed with exporter readiness,
gateway/AdGuard/Kepler UDP/TCP, identity, SWAG, and dependent checks. The result
artifact is `passed`, `original_failure_rc=0`, and `recovery_failed=false`.
An immediate independent privileged exporter diagnostic again reported all
three families, the full observation passed, and the ephemeral namespace was
removed. P3 is complete. The active gate returns to P2 backup/restore evidence
and its separately bound mutation approval.

1. Reconfirm DHCP resolvers and vanguard listeners/routes.
2. Design a LAN-reachable secondary that resolves fleet and external names;
   public DNS is forbidden as normal fallback.
3. Land network ownership in homelab-iac and host support in desktop-nixos.
4. Create/inspect saved plan from wired LAN; stop on unrelated drift.
5. Apply and probe from a generic LAN client.
6. Stop AdGuard through approved workflow; prove fleet/external resolution via
   secondary; restore and verify both resolvers.

### P4 — full AdGuard Terraform ownership

Provider admission and non-live modeling advanced on 2026-07-16. Homelab-IaC
`fdf4d80` exact-pins `gmichels/adguard` 1.7.0 and proves create, refreshed
zero-drift plan, unrelated DNS update with DHCP disabled, second zero-drift
plan, and destroy against a loopback-only disposable AdGuard instance using
dummy credentials and temporary state. An initial refresh-only assertion was
corrected because exit code 2 there represented state refresh rather than an
actionable configuration diff; two subsequent stock-provider lifecycle runs
passed. No provider fork is required.

Homelab-IaC `e5b2d00` adds the production-shaped, non-secret `adguard_config`
model for provider-supported DNS, cache, filtering, protection, safe-search,
query-log, statistics, blocked-service, and global rewrite settings. The model
explicitly excludes credentials, users, TLS key/certificate material, DHCP,
runtime data, and provider-unsupported bootstrap fields. Those exclusions stay
Servarr/Vault/SOPS-owned until a separately proven representation exists.
OpenTofu init/validate, exact lock metadata, Terragrunt render, sensitive-key
rejection, formatting, and the disposable lifecycle are green. At that
checkpoint, no live import, plan, apply, API request, or YAML removal had
occurred; the next gate was the wired-host import.

The wired-host import then completed for the existing singleton without changing
AdGuard. The first saved-plan apply through the community provider failed closed
with AdGuard HTTP 400 because the provider serialized an invalid empty DHCPv4
object during an unrelated update; no apply completed and the failed saved plan
was retired. This converted the previously suspected provider limitation into a
reproduced production-shape defect.

The provider ownership decision was to maintain the public
`ErikBPF/terraform-provider-adguardhome` fork rather than preserve a permanent
dummy-DHCP workaround. Provider commit `57a447c` rebrands the Registry address
and resource prefix, retains upstream MIT history, fixes disabled-DHCP writes,
normalizes singleton/TLS refresh state, removes secret-bearing diagnostics,
adds focused regression tests, and establishes pinned CI, acceptance, signed
release, checksum, SBOM, and provenance workflows. Unit/race/vet/build,
generated documentation, workflow lint, and an unsigned multi-platform
GoReleaser snapshot passed. The accepted v1 direction is one resource per real
AdGuard API concern; v0.1 retains compatible schemas under the new
`adguardhome_*` prefix for safe adoption first.

P4 completed on 2026-07-19. Homelab-IaC `ff5e633` adopted the owned Registry
provider, `369f0d5` pinned signed release `0.1.8`, and `1b91cab` migrated
filtering state. The production config singleton was already migrated. From a
wired LAN client, the disposable lifecycle passed and both `adguard/config`
and `adguard/filtering` refreshed to zero-change plans. The first config plan
exposed an unrelated stale networking stack: primary DNS timed out while the
Kepler secondary answered. Recovery used `just kick-stack discovery
networking`; primary/secondary fleet resolution and MinIO backend health then
passed. No production apply was needed because both saved plans were no-op.
Provider-unsupported bootstrap/runtime fields remain Servarr-owned.

#### Provider admission

1. Isolate unrelated homelab-iac dirty work.
2. Exact-pin provider and verify lockfile.
3. Reproduce disabled-DHCP lifecycle against disposable target.
4. Fix or reject provider if full create/read/update/delete is unsafe. Never
   omit supported settings merely to avoid the bug.

#### Export, model, import

1. Export full API state and YAML rollback copy without committing secrets.
2. Model every supported DNS/cache/rate/block/client/PTR/filter/rewrite/rule/
   query/stat/safe-service/schedule/DHCP/lease/TLS setting.
3. Import existing resources and require zero unexplained drift after refresh,
   restart, and runtime activity.
4. Add provider tests and manual recovery.

#### Wired saved-plan apply

1. Prefetch; capture baseline probes; create/checksum/inspect saved plan.
2. Apply only that plan while probing LAN DNS, fleet rewrite, external lookup,
   blocked response, and API.
3. Auto-restore YAML and prior Terraform state/config within five minutes on
   critical failure.
4. Remove overlapping servarr declarations only after green apply/zero drift.

### P5 — canonical AdGuard volume

1. Resolve empty `discovery_adguard_work` collision without unauthorized reuse
   or deletion.
2. Create approved `discovery-adguard-work`.
3. Ledger, stop AdGuard, fresh snapshot/archive, verify backup.
4. Copy metadata-preserving; compare source/destination; stop on delta.
5. Update explicit mapping, recreate, repeat P2/P4 probes.
6. Reboot discovery and repeat probes.
7. Retain `networking_adguard_work` and all protection.

### P6 — kindle-dash protected automatic releases

**Status 2026-07-19:** protected publication, verified consumer pin, exact
Harbor mirror, and managed Discovery deployment are complete. Kindle-dash run
`29705578290` published and verified `v0.3.2` at
`sha256:0776e18e4f2097ade4872b63e507d482430a20c855dfebb95bb3834906df00a3`.
The narrow `erikbpf-kindle-release` GitHub App created Servarr PR `#52`; after
its installation gained read-only Actions permission, the App identity read
all eight green checks and merged the PR. Servarr PR `#53` (`c6b6b32`) then
locked complete OCI-index copying with Skopeo `--all --preserve-digests`.

Discovery receives the project-scoped Harbor robot only through the root-only
Vault Agent render. `cosign` verified the exact protected-main workflow
identity; Harbor preserved the complete source index digest. The host reset to
merged Servarr `main`, recreated `podman-compose-kindle-dash`, and passed the
fixed gates: expected running digest, Compose owner `kindle-dash`, external
`discovery_kindle_dash_data` mounted at `/data`, healthy container, and valid
PNG. No administrator or personal credential was used.

**Status 2026-07-21:** P6 is complete. The fixed pull-based release agent
promoted signed `v0.3.4` at
`sha256:2f06bcf3bcb3405a77cd4e5a22434d60cdf87f703b574103c0db8a4611abc182`
from merged Servarr commit `62e22346bd87bce26f6afec036e3fe4e40407d88`.
Its enabled timer triggered unattended at 13:01:49 -03 and exited successfully;
the container remained healthy with the expected external data volume and a
valid PNG.

The v0.3.3 controlled post-recreate failure drill restored the previous pin
and image without replacing the data volume. Phase-interruption fixtures prove
resume only after revalidation. A revoked provider credential produced only
`external-reporting-unavailable`, left the running stack untouched, and cleared
after credential recovery. Atomic state, systemd status, node-exporter metrics,
GitHub checks, and Discord reporting carry the same release snapshot. The
agent's 91 deterministic tests cover promotion, rollback, resume, degraded
reporting, and fixed-input boundaries.

#### Tests and release semantics

1. Add deterministic PNG and Claude/Codex/opencode parser fixtures.
2. Test minor default, patch, major, none, and conflicting labels.
3. Protect `main`: PR-only, required CI, no force pushes, owner bypass.
4. Create mutually exclusive release labels.

#### Signed publication

1. Build amd64 from protected merge commit and calculate SemVer from latest
   valid tag.
2. Publish immutable GHCR digest; generate SBOM/provenance.
3. Cosign keyless with expected repo/workflow identity; verify all artifacts.

#### Verified servarr pin

1. Provision narrow GitHub App.
2. Open single-file tag/digest PR.
3. Require tag existence, signature identity, immutable digest, Compose render,
   and state-volume checks; auto-merge only green.

#### Pull-based discovery promotion

1. Fixed root agent; no arbitrary repo/stack/command/path/tag/image input.
2. Verify signed GHCR metadata; mirror exact digest to scoped Harbor; prove
   parity and merged servarr pin.
3. Pull via documented service; recreate managed kindle stack.
4. Gate running digest, owner, volume, health, and PNG.

#### Rollback and reporting

1. Force hard-gate failure; prove automatic old pin/image restoration without
   touching volume.
2. Force provider-auth failure; prove degraded-only status.
3. Interrupt each persisted phase; prove safe resume after revalidation.
4. Align atomic state, systemd, Alloy, metrics, GitHub, and Discord on identical
   version/digest/phase/failure/rollback.

### P7 — remaining stateful stacks

One service or tightly coupled DB group per slice: explicit adopt/recreate,
snapshot/archive/copy/compare, canonical switch/recreate, smoke, reboot, retain.

1. PostgreSQL, Redis, OpenBao consumers, Vaultwarden, MinIO, ClickHouse and DB
   state. Require app dumps and successful backup cycle before cleanup.
2. Plex, Jellyfin, Jellystat, Tautulli, arr/media metadata.
3. Grafana, Prometheus, Loki, healthchecks, Scrutiny, other tools.
4. Cache/rebuildable volumes only after regeneration proof.

Anonymous/zero-link/zero-byte resources are not proven orphans.

### P8 — Terraform control-plane inventory

Inventory Grafana, Harbor, PocketID, MinIO, Cloudflare, GitHub, NetBird,
Tailscale, and UniFi. Prefer official/stable `>=1.0`; otherwise require exact
pin/lock, import, zero diff, API export, tests, and manual recovery. Move only
control-plane objects. Keep containers/filesystem state with existing owners.
Keep applies wired, saved-plan, and human-gated. Output a provider admission
decision table with direct evidence.

### P9 — orphan report and deletion approvals

1. Re-inventory after migrations and reboot.
2. Prove no active owner/mount and no unique state or verified backup.
3. Report resource, size, owner, last consumer, backup, retention gate, and
   exact deletion command.
4. Request separate approval for every container, volume, snapshot, archive,
   or remote-state deletion.
5. Delete approved resources one at a time; re-run probes each time.

Protected candidates include `kindle-dash_kindle_dash_data`, colliding
`discovery_adguard_work`, P0 fixture resources, and retained legacy volumes.
Presence alone is not orphan proof.

## 6. Verification matrix

| Surface | Required evidence |
|---|---|
| Desktop | lint, fmt-check, discovery dry-build; full check for shared behavior; post-switch probes |
| Servarr | Compose render, exact digest, volume policy/fixtures, service smoke |
| IaC | format, validate, lock consistency, security, saved plan/checksum, import/zero diff, wired probes |
| Kindle | format/lint, parser fixtures, PNG, image build, SemVer labels, signature/SBOM/provenance |
| Migration | ledger, stopped-service backup, checksum/read/restore/compare, identity/health, rollback, reboot |
| Kepler | SecretSpec drift report, approved manifest hash, exact retirement evidence, retained-state coverage, per-slice gates, reboot, second planner |
| SWAG | nginx, cert SAN/expiry, DNS-01 dry run, HTTPS, LAN PNG, clean logs |
| AdGuard | LAN A/AAAA, rewrite, external, blocked, API, filters/log/stats/rules/exporter, secondary outage |
| Release | signed digest, owner/volume/health/PNG, forced rollback, degraded failure, resume, consistent reporting |

No phase completes without fresh verification output after its final change and
live mutation.

## 7. Approval and credential gates

Stop and request only the narrow missing authority for:

- named container replacement/deletion;
- named volume/snapshot/backup/fixture/remote-state deletion;
- destructive rollback;
- non-wired Terraform apply, unexplained drift, or saved-plan mismatch;
- missing Cloudflare, AdGuard, GitHub App, Cosign/OIDC, Harbor, GitHub status, or
  Discord credentials;
- unapproved GitHub branch-protection/repository-setting changes;
- ambiguous ownership or missing/failed backup.

The current active gate is P7: create per-service ledgers and migrate the
remaining stateful stacks. P6 did not authorize deletion of bind state, volumes,
snapshots, backups, failed journals, P0 fixtures, P1 evidence, or legacy
resources.

## 8. Completion ledger

| Phase | State | Evidence | Remaining gate |
|---|---|---|---|
| P0 | Complete | Servarr `98ecafb`; desktop `50454f9`, `6217215`, `061a1cc`, `5a24439`; retained fixture | P9 cleanup only |
| K0 | Complete | Servarr `1805e1d`; 21 planner fixtures; Kepler dry-build; full flake check | K1 evidence and exact approval manifest |
| K1–K4 | Complete with approved deviation | Exact manifests and force/reset evidence; retained PostgreSQL/Qdrant/MinIO state; disposable Redis reset; final inventory `74c70f4…` | P9 retained-evidence cleanup only |
| K5 | Complete via approved retirement deviation | Reboot verification; AI-serving retirement manifest `de8ce750…`; final audit `71e89e49…` | P9 retained-evidence cleanup only |
| P1 | Complete | Servarr `b676063`; amendment `94781f28…` passed, idempotent, and passed after reboot; desktop `e167be6`; host and SWAG persistence gates | P9 retained-evidence cleanup only |
| P2 | Complete with approved practical recovery deviation | Servarr `9969e35`; transition passed backup/restore, recreate, 15-minute observation, and smoke; terminal bookkeeping failure retained; normal pull/recreate recovery; final inventory `f63ab37f…` | P9 retained-evidence cleanup only |
| P3 | Complete | Desktop through `8eb1212`; approved manifest `d5cf3b59…`: core 24/24 in 1,639 ms, allowed 7-row gateway diagnostic, exact-ID recovery attempt 1, post-restore 37 rows complete, exporter 3/3, namespace removed | P9 retained-evidence cleanup only |
| P4 | Complete | Homelab-IaC through `ff5e633`, `369f0d5`, `1b91cab`; signed provider 0.1.8; disposable lifecycle green; config and filtering production plans no-op; primary DNS recovered through approved recipe | P9 retained-evidence cleanup only |
| P5 | Complete | Servarr `eaa1f4f`; retained ledger/snapshot/archive; canonical mount and reboot probes green | P9 retained-evidence cleanup only |
| P6 | Complete | Protected releases through `v0.3.4`; App-merged Servarr pins; exact Harbor parity; fixed pull agent; v0.3.3 rollback and auth-degradation drills; resume fixtures; aligned reporting; scheduled trigger 2026-07-21 13:01:49 -03; live digest/volume/health/PNG green | P9 retained-evidence cleanup only |
| P7 | Active | P0 inventory | Per-service ledgers |
| P8 | Pending | — | P7 |
| P9 | Pending | Candidate inventory | P8; per-resource approvals |

Completion requires direct, current evidence for all eleven acceptance criteria
in the authoritative proposal and no remaining required work.
