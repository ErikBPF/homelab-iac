# Cognee homelab contextual graph canary

**Status:** Proposed; Falkor manifests and image source prepared, live canary not started
**Date:** 2026-08-17
**Last reviewed:** 2026-08-17
**Owners:** `homelab` for gates and evidence; `homelab-gitops` for the Kepler
workload; `homelab-iac` for LiteLLM routes and consumer policy; Vault for
runtime secret values

## Goal

Test whether one authenticated Cognee service on Kepler can give multiple
homelab users and agents useful relationship-aware recall over history,
external documents, and selected code without becoming a second source of
truth, leaking private material, or adding an unbounded stateful service.

The canary uses PostgreSQL 18 for relational state and FalkorDB for graph and
vector state. BGE-M3 embeddings and `qwen-chat` extraction/generation stay on
homelab hardware behind LiteLLM. The result is a persistent, multi-user canary,
not a highly available service.

## Decision summary

Run one manually synchronized Cognee 1.4.2 canary on Kepler with:

- PostgreSQL 18 + pgvector on a dedicated `20Gi` `nfs-fast` PVC for Cognee
  relational state;
- FalkorDB on a dedicated `20Gi` `nfs-fast` PVC with AOF `everysec` and RDB
  checkpoints, serving both graph and vector indexes;
- one `20Gi` Cognee PVC for application data and caches;
- BGE-M3 embeddings at 1024 dimensions, unchanged from the measured local
  Kepler baseline;
- local `qwen-chat` through LiteLLM for extraction and generation;
- authenticated multi-user mode, dataset ACLs, local-file/HTTP ingestion
  disabled, raw Cypher disabled, and no automated Argo sync.

Do not replace the source-backed retrieval ladder in
[`2026-08-16-local-repository-knowledge-retrieval.md`](2026-08-16-local-repository-knowledge-retrieval.md).
Cognee is an optional contextual layer. Git, current source, tests, decisions,
and runbooks remain authoritative; retrieved relationships are leads to verify.

| Graph option | Decision for this canary | Reason |
|---|---|---|
| FalkorDB | Use | Local server process; concurrent clients; per-dataset graph/vector isolation; persistent OpenCypher store |
| Kuzu | Reject | Embedded file locking and process locality conflict with the multi-user goal |
| Self-hosted Neo4j | Reject | Cognee does not support this combination for multi-user isolation |
| Neo4j Aura | Reject | External storage violates the local-only requirement |

## Current state

- Local GitOps manifests exist for Cognee, PostgreSQL and FalkorDB StatefulSets,
  three PVCs, ingress, ExternalSecret, and default-deny network policy.
- The Argo application is manual-sync only. The live cluster has no `cognee`
  namespace or Argo application, so PostgreSQL 18 starts on a fresh data
  directory; there is no PostgreSQL 17 upgrade path in this canary.
- Cognee `1.4.2` is the exact dependency of Falkor adapter `0.4.0`. The custom
  image source pins both upstream wheels by SHA-256, imports the adapter through
  `sitecustomize.py`, and bakes the BGE-M3 tokenizer at a pinned Hugging Face
  revision for offline runtime. A local build proved all Falkor providers and
  dataset handlers register. The GHCR publish workflow exists; its first signed
  digest is not yet published or pinned, so sync remains blocked.
- PostgreSQL 18, FalkorDB `4.20.3`, adapter dependencies, and BGE tokenizer
  source are version/digest pinned.
- Terraform defines a dedicated Cognee LiteLLM key limited to `bge-m3`,
  `bge-reranker-v2-m3`, and `qwen-chat`, with ephemeral handoff to
  `secret/lab/cognee-litellm` in OpenBao. Cognee uses BGE-M3 and `qwen-chat`;
  reranking remains available but disabled for the storage experiment.
- Kepler's prior embedding experiment measured BGE-M3 retrieval at R@1 `0.84`
  and BGE reranking at `0.87`. Keep BGE-M3 as the baseline rather than reopening
  model selection during the storage experiment.

## Boundaries

### Canonical and derived data

| Data | Authority | Cognee treatment |
|---|---|---|
| Current code and configuration | Owning Git repository | Derived, commit-stamped dataset; verify answers in source |
| Decisions, proposals, runbooks | Owning Git repository | Derived contextual input with path and commit metadata |
| Git history | Git object database | Selected summaries/events, not an unbounded clone dump |
| External documents | Original publisher or retained artifact | Allowlisted input with URL, retrieval date, and license |
| User annotations and feedback | Cognee dataset | Context only; never silently promoted into Git |
| Graphs, embeddings, caches | Cognee stores | Rebuildable derived state |

Never ingest `.env*`, `*.secrets.json`, Sops/Vault material, certificates,
credentials, Terraform state, backups, dependency trees, build outputs, or
`worktrees/`. Repository allowlists and existing `.graphifyignore` exclusions
are the floor, not an override target.

### Egress

BGE-M3 runs on Kepler and `qwen-chat` on Orion, both through LiteLLM. The Cognee
NetworkPolicy permits HTTPS only to LiteLLM's LAN address
`192.168.10.210/32`; arbitrary internet egress is denied. The tokenizer is
baked into the image and forced offline. Continue using synthetic fixtures
until authentication, dataset isolation, deletion, and restore gates pass;
locality alone does not authorize broad ingestion.

### Multi-user model

Use authenticated users and named datasets, not one shared API key and a global
dataset. The canary must exercise:

- a private dataset visible only to its owner;
- a deliberately shared dataset with read-only access for a second user;
- denied cross-user read, write, delete, and graph-query attempts;
- per-dataset Falkor graph and vector handler resolution after restart.

Cognee documentation requires provider/handler compatibility when backend
access control is enabled. The image build already proves handler registration;
the first boot gate must additionally prove two-user dataset isolation against
the live FalkorDB instance before any private ingestion.

## Delivery plan

### P0 — make the deployment claim honest

Before sync:

1. publish and sign the custom Cognee image, then pin its immutable GHCR digest
   in the Deployment; a version tag is not a deployable release. Confirm the
   secret-free package is anonymously pullable or add a Vault-backed pull secret;
2. run Terraform plan/review for the Cognee LiteLLM key and OpenBao handoff,
   then apply leaf-first only after approval;
3. verify the four non-LiteLLM `lab/cognee` Vault values exist without printing
   them and that ESO can read the Terraform-managed LiteLLM key path;
4. render the Argo application and manifests, confirm immutable images, and
   prove ingress/TLS exposure plus the LAN-only LiteLLM egress path;
5. extend the planned 18-question source-backed retrieval benchmark with six
   Cognee-only cases covering ACLs, restart persistence, repeated ingestion,
   deletion, and relationship recall;
6. define a synthetic/public fixture capped at 100 documents or `25MiB`,
   containing code-like symbols, history, contradictory revisions, and a
   secret-canary file that must be excluded;
7. record exact API calls, repetitions, scoring, and a LiteLLM request/token
   ceiling before deploying.

**Gate:** signed image digest pinned, Terraform plan reviewed/applied, secret
paths present, configuration validation and fixture review pass. Any mismatch
blocks sync; do not disable access control to make startup succeed.

### P1 — fresh Kepler canary

Manually sync the Argo application. Prove:

- PostgreSQL reports major version 18 and the `vector` extension is available;
- Cognee reports the intended authentication posture and all probes stabilize;
- FalkorDB reports AOF enabled and distinct graphs per user/dataset;
- BGE requests use local `bge-m3` and generation uses local `qwen-chat` through
  the dedicated LiteLLM key;
- pod restart preserves users, dataset metadata, vectors, graph nodes, and
  source provenance.

Record cold start, idle and peak CPU/memory, PVC growth, ingestion duration,
and LiteLLM request/token counts. Stop at the P0 ceiling rather than tuning
concurrency or expanding the corpus.

**Gate:** zero crash loops, zero unclassified egress, zero secret-canary hits,
and exact record-count/query equivalence across one controlled restart.

### P2 — retrieval and multi-user benchmark

Run the planned 18-question source-backed benchmark plus the six Cognee cases,
split across:

- exact fact lookup;
- multi-hop relationship questions;
- revision/history conflicts;
- external-document-to-code relationships;
- missing, deleted, and unauthorized data.

Compare Cognee with the existing source-backed retrieval ladder. Score
correctness, expected-source localization, provenance, stale-fact rejection,
cross-user isolation, warm retrieval latency, and end-to-end latency. Measure
at one and three concurrent authenticated users. Repeat each timed query five
times after one untimed warm-up; report the sample count with p50 and p95.

Minimum retention evidence:

- no unauthorized result, write, deletion, or existence leak;
- every accepted code/config answer resolves to a current repository path and
  commit and survives source verification;
- stale and deleted fixtures are absent after refresh;
- Cognee improves at least three relationship questions without regressing
  exact questions;
- warm retrieval p95 is at most `5s` and end-to-end p95 at most `15s` over the
  fixed local benchmark, with no `5xx` at three concurrent users.

**Gate:** retain only if relationship quality or repeated-context recall adds
measurable value over Graphify + exact source search.

Passing P2 proves mechanics and public/synthetic retrieval only. It does not
authorize private homelab ingestion or prove value on private homelab content.

### P3 — backup and recovery proof

PostgreSQL relational state and FalkorDB graph/vector state form one logical
service. A valid backup must not capture unrelated points in time.

1. stop writes and scale Cognee to zero;
2. take a PostgreSQL logical backup and a FalkorDB AOF/RDB snapshot under one
   run identifier;
3. record image digests, schema/migration version, BGE dimensions, dataset IDs,
   row/node counts, and checksums;
4. restore into disposable PVCs and run the benchmark subset plus ACL negatives;
5. restart the original canary only after the evidence bundle is complete.

**Gate:** restored counts, ACLs, searches, and graph relationships match. A
PostgreSQL-only backup is failure, not partial success.

### P4 — decide, narrow, or delete

Choose one outcome:

- **Delete:** value or performance gate fails; remove the Application, namespace,
  and disposable PVCs after retaining sanitized benchmark evidence.
- **Keep as bounded single-replica service:** Falkor persistence, NFS behavior,
  restore, and three-user concurrency pass; document the single-instance ceiling.
- **Open an HA follow-up:** only if measured availability requirements justify
  Falkor replication/cluster complexity. Reuse the same benchmark and restore
  contract.

Production graduation additionally requires monitoring, alerting, scheduled
backups, retention, upgrade rehearsal, a supported graph backend decision, and
an approved private-content LLM route or explicit external-egress policy.

## Failure modes and controls

| Failure | Control |
|---|---|
| Private source leaves the homelab | Dedicated local-only LiteLLM allowlist; LAN-only NetworkPolicy; offline tokenizer; LiteLLM audit metadata |
| Dataset handler mismatch disables isolation or boot | Fail startup; test two users and required handlers; never bypass with single-user mode |
| Falkor AOF/RDB or NFS semantics lose graph state | AOF every second, RDB checkpoints, restart test, coordinated restore drill |
| PostgreSQL and Falkor backups disagree | Stop-write backup set with one run ID and cross-store count/query proof |
| Stale code becomes confident context | Commit metadata, deleted/revision cases, source verification before action |
| Cognee duplicates Graphify and wiki ownership | Keep Cognee derived and optional; preserve retrieval ladder and Git authority |
| External documents violate license or provenance | Allowlist, retain URL/date/license, no bulk mirroring by default |
| Cost or latency grows without bound | `100` document/`25MiB` fixture cap, fixed benchmark, request/token ceiling, PVC/resource measurements, delete gate |
| One service becomes fleet-critical | No build/deploy dependency, no automatic client injection, manual canary sync |

## Non-goals

- indexing every repository or all Git history during the canary;
- replacing Graphify, `rg`, Git, the Hermes wiki, or source review;
- high availability, horizontal Cognee scaling, or a zero-downtime database;
- Falkor clustering, self-hosted Neo4j, or another graph service before canary evidence;
- enabling raw Cypher, arbitrary URL ingestion, or local-path ingestion;
- changing BGE-M3, adding a reranker, or running another embedding bake-off;
- accepting private-data egress by implication.

## Rollback

Because the live namespace and Application do not yet exist, pre-sync rollback
is deletion of the unmerged canary manifests. After sync, stop ingestion, retain
only sanitized evidence, delete the Argo application, namespace, and explicitly
identified Cognee PVCs, then revoke the Cognee Vault credentials and LiteLLM
consumer access. Canonical Git sources and the Hermes wiki remain unchanged.

## Next gate

Complete P0 only: merge and run the signed image workflow, pin its digest, review
and apply the two Terraform units leaf-first, verify Vault paths, extend the
benchmark, and prepare the bounded synthetic multi-user/secret-negative fixture.
Do not sync the application or ingest homelab content yet.

## References

- [Cognee setup and database guidance](https://docs.cognee.ai/setup-configuration/overview)
- [Cognee security and multi-user isolation](https://docs.cognee.ai/setup-configuration/security)
- [Cognee permissions and provider/handler compatibility](https://docs.cognee.ai/setup-configuration/permissions)
- [Cognee Kuzu dataset handler](https://docs.cognee.ai/core-concepts/multi-user-mode/dataset-database-handlers/existing-dataset-database-handlers/kuzu)
- [Cognee FalkorDB community handler](https://docs.cognee.ai/core-concepts/multi-user-mode/dataset-database-handlers/existing-dataset-database-handlers/falkor)
- [Cognee official Falkor image-registration recipe](https://github.com/topoteretes/cognee-integrations/blob/main/integrations/openclaw/skills/falkor/SKILL.md)
- [FalkorDB persistence guidance](https://docs.falkordb.com/operations/persistence.html)
- [Local repository knowledge and retrieval](2026-08-16-local-repository-knowledge-retrieval.md)
- [Stateful stack and release hardening](2026-07-13-stateful-stack-release-hardening.md)
- [Hermes AgentMemory integration history](2026-06-25-hermes-agentmemory-integration.md)
