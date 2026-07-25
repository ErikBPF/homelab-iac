# Stateful stack and release hardening

**Status:** In progress — P0, Kepler K0–K5, and P1–P6 are complete. P7
per-service ledgers and remaining stateful-stack migrations are active.

**Execution update (2026-07-25):** The completed rollout through P6 is recorded
in the execution plan. This proposal remains authoritative for architecture and
acceptance criteria; the execution plan is authoritative for rollout order and
live status.

**SecretSpec authority update (2026-07-21):** Discovery SecretSpec scope,
ordering, and status now live in Servarr's
[`machines/discovery/secretspec-inventory.md`](https://github.com/ErikBPF/servarr/blob/097280976683ab82e0dbe53bd60e7b8b07d5613a/machines/discovery/secretspec-inventory.md).
This proposal retains the architecture and historical acceptance evidence; it
does not define future Discovery SecretSpec profiles.

## 1. Summary

Make discovery's stateful Compose stacks and the kindle-dash release path safe
to operate without relying on implicit Compose project names, workstation-only
knowledge, or mutable image tags.

The work has three connected outcomes:

1. Every stateful servarr workload has an explicit owner, stable storage names,
   app-consistent backup, measurable migration gates, and a tested rollback.
2. AdGuard and SWAG move as far as their stable APIs allow into `homelab-iac`
   while servarr remains the owner of containers and filesystem state.
3. A merge to kindle-dash `main` produces a signed release, pins it in servarr,
   mirrors it into Harbor, deploys it through discovery's servarr unit, and
   reports or rolls back the result without a general-purpose LAN runner.

This is operational work. Completion requires live migration, reboot, DNS,
ingress, registry, container, and rollback evidence; static evaluation alone is
not sufficient.

## 2. Why now

The kindle-dash `v0.1.1` deployment exposed several coupled weaknesses:

- The stack existed in servarr but was absent from discovery's declared stack
  list, so the standard recreate recipe targeted a nonexistent systemd unit.
- Moving ownership from Compose project `discovery` to project `kindle-dash`
  changed the implicit volume name and started the replacement container with
  empty OAuth state.
- The old container name blocked the managed unit until ownership was migrated.
- The release required a manual GitHub tag, workflow polling, OpenBao credential
  retrieval, Harbor mirroring, digest pinning, cross-repo commits, host pull,
  recreation, and service checks.
- A healthy HTTP endpoint did not prove that Claude and Codex credentials had
  survived the move.

The immediate incident is resolved: kindle-dash `v0.1.1` is live from Harbor,
the `podman-compose-kindle-dash` unit owns it, and the existing
`discovery_kindle_dash_data` volume is mounted explicitly. The empty replacement
volume remains intentionally undeleted pending verified cleanup.

These failure modes apply to every stateful stack that still relies on a
Compose-generated physical volume name. Essential DNS and ingress services are
the first migration targets because their blast radius is highest.

## 3. Goals and non-goals

### Goals

- Make state ownership independent of Compose project and stack renames.
- Adopt every existing volume in place before copying it.
- Move adopted volumes to explicit canonical names with checksum and rollback
  evidence.
- Migrate SWAG and AdGuard separately, with SWAG first.
- Make every AdGuard setting exposed by the stable provider authoritative in
  Terraform.
- Keep Cloudflare edge objects declarative without making Terraform a container
  or filesystem deployment tool.
- Automate kindle-dash versioning, signing, publishing, pinning, mirroring,
  deployment, rollback, and reporting.
- Reuse the resulting validation, backup, smoke, and rollback contracts for the
  remaining discovery stacks.

### Non-goals

- Terraform ownership of Docker containers, nginx files, certificate caches, or
  mutable application files.
- Mutable `latest` image deployment.
- A privileged self-hosted GitHub Actions runner on the home LAN.
- Automatic Terraform apply against LAN DNS, DHCP, or ingress control planes.
- Automatic global Docker pruning or deletion of legacy volumes.
- Combining SWAG and AdGuard into one migration event.
- Replacing servarr as the owner of household Compose workloads.

## 4. Locked decisions

### 4.1 One owner per concern

- `desktop-nixos` owns host orchestration, declared stack units, release-agent
  service hardening, fleet addressing, and monitoring integration.
- `servarr` owns Compose definitions, container lifecycle, explicit volume
  mappings, mutable application state, and immutable image pins.
- `homelab-iac` owns provider-backed external control planes: AdGuard API
  configuration, Cloudflare DNS/tunnels/Access/rate limits/tokens, and future
  provider-backed application objects.
- `kindle-dash` owns renderer code, tests, image build, SemVer calculation,
  signing, SBOM, provenance, and GHCR publication.

Consumers publish and pin. No build or apply reads live source from a sister
repo, and discovery never hand-edits its servarr clone.

### 4.2 Volume adoption precedes migration

For every stateful named volume:

1. Inventory the live container, Compose project, mount target, physical volume,
   size, ownership, and backup coverage.
2. Change Compose to reference the existing physical volume explicitly as
   external storage.
3. Recreate and smoke-test without copying data.
4. Immediately proceed to canonical migration once the smoke gate passes; no
   multi-day soak is required.
5. Stop only the affected service, snapshot state, create the canonical volume,
   copy with metadata preserved, compare source and destination, update the
   explicit mapping, and recreate.
6. Retain the legacy volume through successful smoke tests and one host reboot.
   High-impact database volumes remain until a full backup cycle is verified.
7. Delete only after a separate explicit confirmation.

Canonical physical names use `<host>-<service>-<purpose>`, for example
`discovery-adguard-work` and `discovery-postgres-data`. Every canonical state
volume is declared explicitly and externally; Compose must never derive its
physical name from the project.

### 4.3 Backup gate

Each migration uses an app-consistent two-layer backup:

- stop only the affected service;
- create a Btrfs snapshot covering bind-mounted state;
- export each named volume into a checksum-verified archive;
- prove the archive can be listed and read before mutation;
- retain snapshot and archive until rollback protection expires.

Existing restic backups remain required but do not replace the migration-local
snapshot and archive.

### 4.4 Essential stack order

SWAG and AdGuard migrate separately:

1. SWAG in-place ownership validation and backup.
2. SWAG smoke tests for HTTP/HTTPS ingress, proxy routes, wildcard certificate,
   and Cloudflare DNS-01 renewal path.
3. Canonical SWAG state migration where any implicit named state remains.
4. AdGuard in-place read-only preflight.
5. Secondary DNS implementation and outage validation.
6. AdGuard in-place mutation and unchanged-behavior smoke tests.
7. Full AdGuard Terraform migration.
8. Canonical AdGuard work-volume migration.

SWAG goes first because Terraform reaches AdGuard through the SWAG hostname.

### 4.5 Maximum safe Terraform ownership

AdGuard Terraform becomes authoritative for every setting exposed by the
`gmichels/adguard` `v1.7.0` provider, including:

- DNS upstream and bootstrap resolvers;
- cache, rate-limit, blocking, client allow/block, and local PTR settings;
- filtering settings, rewrites, user rules, and list filters;
- query log and statistics;
- Safe Browsing, Safe Search, parental control, blocked services and schedules;
- DHCP and static leases if enabled;
- API-exposed TLS configuration.

The singleton AdGuard configuration must be generated from the live API state,
planned to zero unexplained drift, and migrated during a short maintenance
window. `AdGuardHome.yaml` remains bootstrap/runtime persistence only. Servarr
continues to own container lifecycle, bind mounts, authentication bootstrap,
and settings absent from the API.

SWAG Terraform ownership stops at Cloudflare objects:

- DNS records;
- tunnels and routes;
- Access policies;
- rate limits;
- least-scope DNS-01 token.

Servarr keeps the SWAG container, nginx/proxy configs, certificate cache, and
init scripts. Terraform must not write into the SWAG filesystem.

### 4.6 Provider admission policy

Prefer official or stable `>=1.0` providers. A community or pre-1.0 provider is
allowed only when all of these exist:

- exact version constraint and committed lockfile;
- import proof and zero-diff baseline;
- API export backup;
- provider-specific tests;
- documented manual recovery path.

Later phases inventory Grafana, Harbor, PocketID, MinIO, Cloudflare, GitHub,
NetBird, Tailscale, and UniFi. Provider-backed control-plane objects may move to
Terraform; containers and mutable filesystem state do not.

### 4.7 Terraform apply remains human-gated

CI runs formatting, validation, security checks, and speculative plans.
Production apply runs explicitly from a wired LAN host through the owning repo's
recipe, using a saved plan and post-apply probes. Merges never silently mutate
DNS, DHCP, ingress, or application control planes.

### 4.8 Automatic kindle-dash release policy

Kindle-dash `main` becomes PR-only with required CI, no force pushes, and an
explicit owner bypass for emergencies. Every merge releases directly:

- no release label: minor bump;
- `release:patch`: patch bump;
- `release:major`: major bump;
- `release:none`: no release;
- conflicting labels: fail without publishing.

CI derives the next version from the latest valid SemVer tag. Source must
already be committed; release automation does not bundle dirty work or create
infrastructure commits.

The release workflow builds the amd64 renderer image, publishes its immutable
digest to GHCR, produces SBOM and provenance, and signs the digest with keyless
Cosign/OIDC. Discovery accepts only a signature from the expected kindle-dash
release workflow and repository.

### 4.9 Git pin is a deployment gate

A narrowly scoped GitHub App opens a servarr PR changing only the kindle-dash
tag and digest. CI proves the tag exists, digest is signed, and Compose renders;
then the PR auto-merges. The discovery release agent deploys only when:

1. the signed GHCR release exists;
2. the Harbor mirror digest matches GHCR;
3. merged servarr `main` pins that exact tag and digest;
4. the local clone resets to that servarr commit.

Runtime-only pins and mutable tags are forbidden.

### 4.10 Pull-based LAN promotion

Public GitHub runners cannot reach Harbor or discovery. A dedicated system
service on discovery polls authenticated release metadata and performs only the
fixed kindle-dash promotion sequence. It is not a general-purpose self-hosted
runner and cannot execute repository-provided shell commands.

The service uses a root-owned fixed script, a kindle-dash allowlist, strict
SemVer and digest validation, a scoped GitHub read credential, and the scoped
Harbor robot. Docker access is root-equivalent, so arbitrary command, repository,
image, stack, and path inputs are rejected. Systemd sandboxing is enabled where
compatible with the Docker socket and required state paths.

### 4.11 Deployment health and rollback

Hard deployment gates are:

- expected signed digest is running;
- servarr systemd unit is the container owner;
- expected persistent volume is mounted;
- container health is healthy;
- dashboard PNG renders successfully.

Claude, Codex, and opencode fetch failures mark the deployment degraded and
alert, but do not trigger rollback. They depend on external providers and
rotating credentials; parser behavior is locked by CI fixtures.

If a hard gate fails after deployment, restore the prior servarr pin, recreate
the old image, verify the rollback gates, and fail the release. The persistent
volume is never deleted or replaced during image rollback.

### 4.12 Observability and reporting

The release agent persists atomically:

- last observed release;
- last successful tag, digest, and servarr commit;
- current phase and timestamps;
- failure reason;
- rollback target and result.

It reports through systemd status, structured journald logs collected by Alloy,
and node-exporter textfile metrics. Failures update the GitHub deployment/check
and the existing incidents Discord webhook with version, digest, failed gate,
rollback result, and exact recovery command. Credentials and environment dumps
are never logged.

## 5. Target flows

### 5.1 Stateful volume migration

```text
inventory live mount
  -> app-consistent snapshot + archive
  -> explicit reference to existing physical volume
  -> recreate + smoke
  -> stop affected service
  -> copy to canonical volume + compare
  -> switch explicit mapping
  -> recreate + smoke
  -> reboot + verify
  -> retain legacy volume pending explicit deletion
```

### 5.2 Kindle-dash release and deployment

```text
protected main merge
  -> resolve release label + calculate SemVer
  -> test/build/SBOM/provenance/sign
  -> publish immutable GHCR digest
  -> GitHub App opens verified servarr pin PR
  -> CI auto-merges pin
  -> discovery agent verifies release + signature
  -> mirror GHCR digest to Harbor
  -> verify digest parity + merged pin
  -> pull servarr main + recreate managed stack
  -> hard health gates
       success -> record/report deployed
       failure -> restore prior pin/recreate/verify/report
```

## 6. Phased rollout

### P0 — Audit and safety tooling

- Inventory discovery containers, Compose projects, declared systemd units,
  bind mounts, named volumes, sizes, ownership, backup coverage, and orphaned
  resources.
- Classify state impact: essential edge, databases/control plane, media
  metadata, monitoring/tools, cache/rebuildable.
- Add validation that rejects new or changed implicit state volume names unless
  narrowly allowlisted for an active migration.
- Add scoped snapshot, archive, compare, smoke, rollback, and orphan-report
  helpers.
- Prove helpers on disposable fixture volumes before production state.

### P1 — SWAG in-place adoption

- Confirm servarr's bind-mounted SWAG config is the only active state source.
- Take app-consistent Btrfs snapshot and archive.
- Recreate through the managed networking unit.
- Verify HTTP/HTTPS routes, wildcard certificate files, certificate validity,
  DNS-01 credential path, renewal dry run or safe equivalent, and representative
  internal services.
- Migrate any discovered implicit named state to canonical naming; otherwise
  record that no copy is required.

### P2 — AdGuard in-place adoption

- Explicitly bind the existing `networking_adguard_work` volume.
- Snapshot bind-mounted configuration and archive work volume.
- Recreate without data copy.
- Compare live DNS behavior before and after: LAN query, homelab rewrite,
  external lookup, blocked-domain response, API health, filter count, query log,
  and exporter metrics.

### P3 — Secondary DNS gate

- Verify LAN DHCP advertises a working secondary fleet resolver.
- If absent, add a LAN-reachable Kepler CoreDNS secondary before AdGuard
  maintenance; preserve vanguard as the tailnet-only offsite resolver.
- Test homelab and external resolution with AdGuard stopped.
- Do not use public DNS as the normal fallback because it cannot resolve fleet
  names.

### P4 — Full AdGuard Terraform ownership

- Export the full live API configuration and YAML rollback copy.
- Model every provider-supported setting in the singleton Terraform resource.
- Import existing resources and require zero unexplained drift.
- Apply from wired LAN during maintenance.
- Probe critical DNS behavior continuously.
- Roll back automatically after five minutes if LAN DNS, homelab rewrite,
  external resolution, blocked-domain response, or API health fails.
- Remove overlapping servarr declarations only after successful apply and
  verification.

### P5 — AdGuard canonical volume migration

- Create `discovery-adguard-work`.
- Stop AdGuard, take fresh snapshot/archive, copy data with metadata preserved,
  and compare.
- Change the explicit mapping, recreate, and repeat the P2/P4 probes.
- Reboot discovery and repeat probes.
- Retain `networking_adguard_work` until explicit cleanup approval.

### P6 — Kindle-dash CI/CD

- Protect `main` and create mutually exclusive release labels.
- Implement automatic SemVer calculation with minor default.
- Add parser fixtures for current Claude/Codex payload variants and renderer
  smoke tests.
- Publish signed digest, SBOM, and provenance.
- Create scoped GitHub App pin PR and auto-merge checks.
- Add fixed discovery release agent, state, metrics, logs, degraded status,
  rollback, and GitHub/Discord reporting.
- Exercise successful release, degraded provider fetch, hard-gate rollback, and
  recovery from interruption at every persisted phase.

### P7 — Remaining stateful stacks

Repeat adopt-first/copy-second flow in blast-radius order:

1. databases and control-plane state: PostgreSQL, Redis, OpenBao consumers,
   Vaultwarden, MinIO;
2. media metadata: Plex, Jellyfin, Jellystat, Tautulli, and arr applications;
3. monitoring and tools: Grafana, Prometheus, Loki, and remaining services;
4. cache or rebuildable volumes.

One service or tightly coupled database group migrates per change. No bulk
rename event.

### P8 — Terraform capability expansion

- Inventory stable/importable providers for Grafana, Harbor, PocketID, MinIO,
  Cloudflare, GitHub, NetBird, Tailscale, and UniFi.
- Apply the provider admission policy.
- Move only control-plane objects with zero-diff imports and recovery exports.
- Keep Terraform apply wired-LAN and human-gated.

### P9 — Orphan retirement

- Confirm active owners and mounts after reboot.
- Prove orphan candidates contain no unique state or have verified backups.
- Report exact scoped cleanup commands.
- Request explicit deletion approval for each state-bearing resource.
- First candidate: the empty `kindle-dash_kindle_dash_data` volume created during
  the project-ownership migration.

## 7. Verification contracts

### Repository gates

- `desktop-nixos`: lint, format check, structure check, discovery dry-build, and
  full flake check for orchestration changes.
- `servarr`: Compose config rendering, explicit-volume validation, immutable
  digest verification, and stack-specific smoke tests.
- `homelab-iac`: format, validate, provider lock consistency, security checks,
  saved speculative plan, import/zero-diff proof, and post-apply probes.
- `kindle-dash`: parser fixtures, PNG render, container build, signature and
  provenance verification, and release-label tests.

### Live stack gates

- Systemd unit active and correct Compose project label.
- Expected image digest and volume mounts.
- Healthy container with no restart loop.
- Service-specific API and user-path probes.
- Logs and metrics present after recreate.
- Reboot persistence.
- Successful rollback drill before legacy state deletion.

### AdGuard gates

- LAN A/AAAA query succeeds.
- Fleet hostname rewrite resolves correctly.
- External name resolves through intended upstream.
- Known blocked domain returns configured blocking response.
- API health, query log, stats, filters, rewrites, user rules, and exporter
  remain healthy.
- Secondary resolver answers fleet and external names while AdGuard is stopped.

### SWAG gates

- HTTP-only Kindle route remains LAN-restricted and renders PNG.
- Representative HTTPS services return valid certificates and expected routes.
- Wildcard certificate chain and expiry are valid.
- Cloudflare DNS-01 token remains least-scope and usable for renewal.
- nginx config test and SWAG logs are clean.

## 8. Failure handling

- Every mutating phase records its pre-change owner, digest, volume, Git commit,
  and backup identifiers.
- A failed in-place adoption restores the old Compose mapping and recreates the
  prior owner.
- A failed canonical copy switches the mapping back; the source volume remains
  untouched.
- A failed AdGuard Terraform apply rolls back within five minutes using the YAML
  snapshot and previous Terraform configuration/state, then re-runs DNS probes.
- A failed image deployment restores the prior servarr pin and image while
  preserving volume state.
- Provider API failures during image deployment are degraded alerts, not image
  rollback triggers.
- Interrupted release-agent work resumes from persisted phase after revalidating
  all prior gates; it never assumes a previous command completed.

## 9. Security constraints

- Secrets remain sops/OpenBao-managed and never enter git, logs, image labels,
  Terraform plans, or workflow artifacts.
- GitHub App permissions are limited to the kindle-dash pin PR path and required
  metadata.
- Harbor robot remains project-scoped to `library` push/pull.
- Keyless signing identity is constrained to the expected repository and release
  workflow.
- Release agent accepts no arbitrary repository, stack, command, path, tag, or
  image input.
- No workflow receives a general LAN Docker socket.
- No automatic pruning or remote volume deletion.
- Destructive cleanup remains explicitly approved per resource.

## 10. Acceptance criteria

The proposal is implemented when all of these are true:

1. Discovery has a complete state/owner inventory and validation rejects new
   implicit state volumes.
2. SWAG survives managed recreate and reboot with ingress and certificate paths
   verified.
3. AdGuard survives in-place adoption, full Terraform migration, canonical
   volume migration, and reboot with all DNS probes passing.
4. A tested secondary fleet resolver answers during an AdGuard outage.
5. AdGuard Terraform plan has no unexplained drift after runtime activity and
   restart.
6. A merge to protected kindle-dash `main` calculates the correct version,
   publishes and signs an immutable image, auto-merges the verified servarr pin,
   mirrors to Harbor, and deploys through the managed unit.
7. A forced hard-gate failure automatically returns discovery to the prior
   image/pin and reports rollback success.
8. A provider-auth failure produces degraded status without rolling back a
   healthy image.
9. Release state, metrics, Alloy logs, GitHub status, and Discord incident
   reporting identify the same version/digest/phase.
10. Each legacy volume is retained until its reboot/backup gate and explicit
    cleanup approval.
11. Remaining stacks have phased migration records ordered by blast radius.

## 11. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Singleton AdGuard resource overwrites omitted defaults | Export full live API state, model complete resource, require zero unexplained drift, keep YAML/state rollback. |
| DNS outage blocks registry, git, or Terraform dependencies | Stabilize SWAG first, test secondary fleet DNS, prefetch artifacts, use five-minute rollback. |
| Metadata/ownership loss during volume copy | Stop service, preserve metadata, compare source/destination, retain untouched source. |
| Compose project rename creates empty state | Explicit external physical names plus CI validation. |
| Release agent becomes remote-code execution path | Fixed root-owned allowlisted service, no repository scripts, strict signature/digest/input validation. |
| Cross-repo bot bypasses review | Narrow GitHub App, single-file PR, required checks, auto-merge only after verification. |
| External provider outage appears as bad release | Provider fetch is degraded-only; hard gates remain local and deterministic. |
| Community provider breaks after upgrade | Exact pin, lockfile, import test, export backup, manual recovery path. |
| Immediate post-smoke canonical migration misses slow failures | Strong snapshot/archive/rollback gates, reboot test, legacy retention. |

## 12. Open questions

No architectural questions remain from the 2026-07-13 grill. Execution plans
must still discover and record per-volume sizes, ownership, backup identifiers,
copy tools, expected downtime, and stack-specific probes before each migration.
Those are implementation facts, not design choices.

## 13. References

- [`../reference/discovery-stateful-inventory.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/discovery-stateful-inventory.md)
- [`../implemented/2026-06-29-repo-ssot-srp.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-repo-ssot-srp.md)
- [`../reference/harbor-discovery-registry.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/harbor-discovery-registry.md)
- [`../reference/service-exposure.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/service-exposure.md)
- [`2026-07-11-fleet-container-placement-srp.md`](2026-07-11-fleet-container-placement-srp.md)
- [`2026-07-11-netbird-terraform-declarative-admin.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-11-netbird-terraform-declarative-admin.md)
- [AdGuard Terraform provider `adguard_config` resource](https://registry.terraform.io/providers/gmichels/adguard/1.7.0/docs/resources/config)

## 14. Implementation evidence

### P0 — complete (2026-07-13)

- Live inventory captured 2026-07-13; see the reference above.
- Servarr `98ecafb` records current migration debt and rejects new implicit or
  anonymous Compose state volumes. Fixture tests prove canonical/adopted state
  passes and unrecorded state fails closed.
- Desktop commits `50454f9`, `6217215`, and `061a1cc` provide root-only,
  ledger-gated inventory, snapshot, archive, checksum/read, restore, compare,
  smoke, rollback-evidence, and orphan-report tooling plus a fixed systemd
  fixture workflow. No helper deletes resources or executes rollback text.
- The first live fixture attempt failed closed on Git's dubious-ownership
  guard before creating its pre-mutation record or any fixture resource. The
  fix uses command-scoped `safe.directory`; it does not alter global Git trust.
- The successful fixture recorded servarr commit `312fa76`, Compose project
  `p0-fixture`, the immutable SWAG digest `sha256:ce148c3794d2dfcb63eaeed55c516324e800349f8cd57e49ec0eb312fe75f01d`,
  bind source `/home/.stateful-stack-fixtures/p0/source` (`26` bytes,
  `0:0`), mount `/fixture`, and zero expected production downtime before
  mutation.
- Fixture snapshot `/home/.snapshots/stateful-stack-p0-fixture-20260713` is
  read-only, UUID `342edcd9-15a8-0448-8822-3347328d0ff2`. Archive
  `/var/lib/stateful-stack-migrations/p0-fixture/source.tar.zst` passed SHA-256
  and stream/read validation. Restored bytes, ownership, mode, ACL, and xattr
  matched; pinned image/mount smoke passed. Container, source, restore,
  snapshot, archive, checksum, plan, and ledger remain retained.
- Existing `restic-discovery`/`ofelia-discovery` ownership remains ambiguous
  and was deliberately not adopted. Per-migration local snapshots and archives
  protect P1 independently; no production owner was changed during P0.
- P3 discovery found vanguard CoreDNS healthy over Tailscale, but LAN DHCP
  advertises only the UDM. Generic LAN clients therefore lack the required
  secondary fleet resolver.
- P4 discovery reconfirmed `gmichels/adguard` `v1.7.0` previously rejected an
  update with DHCP disabled. Full singleton ownership requires a disposable
  lifecycle test or provider fix before import.
- P6 discovery found kindle-dash `main` unprotected with tag-only unsigned
  releases, no fixtures, no SBOM/signature, and no pin App credentials.
