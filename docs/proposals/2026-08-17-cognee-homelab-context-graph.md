# Cognee homelab contextual graph canary

**Status:** P0 local foundation complete; supported canary healthy, isolated
Cognee `1.5.3` adapter registration passes but remains unsupported, production
unsynchronized
**Date:** 2026-08-17
**Last reviewed:** 2026-08-28
**Owners:** `homelab` for gates and evidence; `cognee-homelab` for packaging,
dataset-routing policy, and local development; `homelab-gitops` for the Kepler
workload; `homelab-iac` for GitHub/LiteLLM control planes; Vault for runtime
secret values

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

The dedicated private `cognee-homelab` repository owns the implementation.
It starts with a local-only minikube canary patterned after
`dataplatform-airflow`'s devenv, DevSpace, and just workflow. SecretSpec is a
new explicit dependency, not copied from that repository: one committed
manifest declares required values, local bootstrap generates them ephemerally,
and production continues to resolve runtime values from Vault through GitOps.

Stable Cognee is now `1.5.3`, but Falkor adapter `0.4.0` still declares the
exact dependency `cognee==1.4.2`. Keep the supported `1.4.2` pair for the first
local health canary and test `1.5.3` in a separate compatibility seam. Neither
`--no-deps` nor a successful import is permission to publish or sync an
unsupported pair.

The unautomated behavior contract is
[`../behaviors/cognee-canary/canary.feature`](../behaviors/cognee-canary/canary.feature).
Its scenarios become tests only after their named shell/API seams are bound and
observed failing before implementation.

| Graph option | Decision for this canary | Reason |
|---|---|---|
| FalkorDB | Use | Local server process; concurrent clients; per-dataset graph/vector isolation; persistent OpenCypher store |
| Kuzu | Reject | Embedded file locking and process locality conflict with the multi-user goal |
| Self-hosted Neo4j | Reject | Cognee does not support this combination for multi-user isolation |
| Neo4j Aura | Reject | External storage violates the local-only requirement |

### Relevant Cognee 1.5.x changes

The upstream `v1.4.2...v1.5.3` history contains several features worth the
compatibility wait: dataset-scoped data and deduplication with stable IDs across
`update()`; dataset IDs and per-dataset rows in search history; principal grant
listing and corrected ACL-reader raw downloads; single-session search and lazy
session-TTL sliding; incremental code-graph/repository ingestion; audit-grade
provenance; and a superuser guard on runtime LLM/vector settings. These align
with branch overlays, private session memory, scope-aware audit, and provenance.
They remain candidate value, not deployed capability, until Falkor compatibility
and the existing ACL contract pass.

## Current state

- `homelab-iac` created private `ErikBPF/cognee-homelab` with read-only Actions
  token defaults and no workflow PR approval. A saved targeted plan applied
  exactly the repository and its two Actions-permission resources; two unrelated
  fleet drifts were observed and intentionally left unapplied.
- The local repository now has devenv, DevSpace, just, and SecretSpec contracts.
  A dedicated rootless-Podman minikube profile runs pinned Cognee `1.4.2`, Falkor
  adapter `0.4.0`, PostgreSQL 18, and FalkorDB. All three pods became ready,
  `/health` passed, a controlled three-workload restart returned healthy, and a
  second deploy reused its Kubernetes Secret without rotating the persisted
  PostgreSQL password. Local model endpoints are deliberately closed, so this
  is packaging/startup/restart evidence, not ingestion or retrieval evidence.
- Live PyPI metadata on 2026-08-28 reports stable Cognee `1.5.3` and Falkor
  adapter `0.4.0` with `cognee==1.4.2`. An isolated digest-pinned `1.5.3`
  `--no-deps` image builds and registers the adapter. ACL, ingestion, search,
  and deletion remain unproved, so publishing and production sync stay closed.
- `homelab-gitops` PR `#85` merged the Cognee, PostgreSQL, FalkorDB, ingress,
  ExternalSecret, PVC, network-policy, image, and manual-Argo source at
  `f489af8`. Its GitHub validation job never started because of account billing,
  so it is not CI evidence. The static Cognee contract and Kubernetes server-side
  dry-run pass locally; full `kubeconform` evidence remains open.
- The live `cognee` namespace exists, but there is no Cognee Argo Application,
  workload, runtime secret, or PVC. The root Argo application is healthy but
  `OutOfSync`. PostgreSQL 18 will therefore start on a fresh data directory;
  there is no PostgreSQL 17 upgrade path.
- Cognee `1.4.2` is the exact dependency of Falkor adapter `0.4.0`. The custom
  image source pins both upstream wheels by SHA-256, imports the adapter through
  `sitecustomize.py`, and bakes the BGE-M3 tokenizer at a pinned Hugging Face
  revision for offline runtime. PyPI metadata confirms the exact dependency and
  wheel hash. Do not independently bump to Cognee `1.5.x`. A local build proved
  all Falkor providers and dataset handlers register. The GHCR publish workflow
  has never run; no signed digest is published or pinned, so sync remains blocked.
- Cognee `1.4.2` has an open upstream dashboard/API `graph-summary` mismatch.
  This API-first canary does not score dashboard completeness; health,
  authentication, documented API calls, and the fixed benchmark remain required.
- PostgreSQL 18, FalkorDB `4.20.3`, adapter dependencies, and BGE tokenizer
  source are version/digest pinned.
- `homelab-iac` PR `#79` merged a dedicated Cognee LiteLLM key limited to `bge-m3`,
  `bge-reranker-v2-m3`, and `qwen-chat`, with ephemeral handoff to
  `secret/lab/cognee-litellm` in OpenBao. Cognee uses BGE-M3 and `qwen-chat`;
  reranking remains available but disabled for the storage experiment. Source
  CI passed; no reviewed apply or live-path evidence has been recorded.
- Kepler's prior embedding experiment measured BGE-M3 retrieval at R@1 `0.84`
  and BGE reranking at `0.87`. Keep BGE-M3 as the baseline rather than reopening
  model selection during the storage experiment.

## Decision map

| Field | Current decision |
|---|---|
| Destination | Decide with fixed evidence whether relationship-aware recall earns one bounded, single-replica service. |
| Actors and outcomes | Operators get source-verifiable context; authenticated users get isolated datasets; agents remain unable to make Cognee authoritative. |
| Settled decisions | Dedicated private implementation repo; supported Cognee `1.4.2` + Falkor adapter `0.4.0` local baseline; isolated `1.5.3` compatibility probe; API-first synthetic canary; manual production sync; Git/Vault authority unchanged. |
| Dependencies | Validated signed image, reviewed IaC apply, runtime secret metadata, and the source-backed 18-question baseline precede live value claims. |
| Fog | Real Falkor/NFS restart behavior, cross-user isolation, deletion, latency, and coordinated restore remain unproven. |
| Open questions | Whether Falkor gains supported Cognee `1.5.3` compatibility; whether the local ACL/handler contract passes; anonymous pull must still fail closed before production sync. |
| Risks and gates | Security, reliability, test, compatibility, and operations gates are P0-P4 below; any ACL or egress failure deletes the canary. |
| Out of scope | Dashboard completeness, private-content ingestion, HA, model selection, reranking, and replacement of source-backed retrieval. |
| Frontier | Decide whether to run the synthetic ACL/routing fixture on the supported local pair or wait for a Falkor adapter supporting stable Cognee; production P0 remains closed. |

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

### Dataset and query architecture

| Scope | Dataset shape | Lifetime and visibility |
|---|---|---|
| Homelab global | `homelab-global` | Durable, shared, cross-repository facts and decisions; one copy only |
| Repository branch | `repo:<repo>:branch:<branch>` | Mutable branch overlay; never duplicates the global base |
| Global knowledge | `knowledge-global` | Durable, reviewed non-repository knowledge |
| Package docs | `package:<name>:<version>` | Durable and versioned; selected only when the active repo depends on it |
| Session | `session:<principal>:<session>` | Private, expiring working memory; never silently promoted |

Every query composes, in precedence order, the private session, active branch
overlay, `homelab-global`, related versioned package docs, then reviewed global
knowledge. Results retain dataset, source path or URL, revision/version, and
ingestion timestamp. Higher-precedence context may supersede an answer but does
not erase contradictory lower-precedence evidence.

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

### Test seams and vertical slices

Use three seams only: the existing `homelab-gitops/tests/cognee-contract.sh` for
static release/configuration policy; one live API runner for authentication,
ACL, restart, deletion, egress, and restore checks; and the source-backed
retrieval benchmark for comparative value. The static seam cannot prove runtime
isolation, the live seam cannot prove retrieval value, and the benchmark must
not become a deployment validator.

| Slice | Observable result | RED then minimum GREEN | Verification, owner, rollout, rollback |
|---|---|---|---|
| S-2 — repository authority | One private repository owns Cognee packaging, local tooling, routing policy, and tests. | RED: the GitHub fleet contract expects `cognee-homelab` before IaC declares it. GREEN: add one least-privilege private repo entry and apply a saved three-create targeted plan. | IaC Bats contract, exact plan, GitHub metadata. `homelab-iac`; archive through IaC if abandoned. |
| S-1 — local contract | A fresh checkout exposes devenv, DevSpace, just, SecretSpec, one behavior contract, and one local stack. | RED: scaffold contract reports every missing surface. GREEN: add only the files needed to start, deploy, inspect, and stop the canary. | Shell contract, Nix evaluation, DevSpace config parse, client dry-run. `cognee-homelab`; delete the local profile. |
| S-0 — compatibility canary | Supported `1.4.2` reaches health locally and `1.5.3` gets an isolated adapter/API probe. | RED: supported stack is absent and the `1.5.3` dependency check reports the hard pin. GREEN: start the supported pair on minikube; record the newer pair as blocked unless its full ACL/handler contract passes. | Rollout status, `/health`, package metadata, handler registration, ACL negatives. `cognee-homelab`; stop/delete the minikube profile. |
| S0 — validated release | Reviewed manifests name one signed immutable Cognee image. | RED: extend the static contract to require `@sha256:`; it fails on the current tag. GREEN: run the existing image workflow, verify the signature, pin the digest, and restore full manifest validation. | Focused contract + server dry-run + full GitOps validation. `homelab-gitops`; no sync. Revert the digest commit or publish a new version—never overwrite the tag. |
| S1 — runtime authority | Approved local models and only sanctioned runtime secret paths exist before workload creation. | RED: `terragrunt plan -detailed-exitcode` returns `2` for the unapplied key and handoff units. GREEN: apply key first, then OpenBao handoff; re-plan to `0`; verify required metadata without values and anonymous image pull. | IaC contract, plans, post-apply metadata, and ESO access proof. `homelab-iac` then Vault/GitOps; revoke key/path on rollback. |
| S2 — synthetic canary | Two users get private/shared datasets with denied cross-user reads, writes, deletes, existence probes, and graph queries across restart. | RED: bind the feature scenarios to one live API runner and observe failure before sync. GREEN: manually sync the exact reviewed revision and fix only the minimum configuration needed for the declared posture. | API runner, provider/handler registration, record equivalence, egress observation, and resource ceiling. `homelab-gitops`; scale to zero and delete app/PVCs on failure. |
| S3 — comparative value | Fixed queries show whether Cognee adds relationship recall without regressing exact source answers. | RED: run the source-backed baseline without Cognee results. GREEN: ingest only the reviewed fixture and add Cognee measurements to the same scoring schema. | Five timed repeats after warm-up, p50/p95, provenance and ACL negatives. `homelab`; stop writes and delete on a failed retention gate. |
| S4 — recoverability | One coordinated PostgreSQL/Falkor backup restores counts, ACLs, searches, and relationships. | RED: the live runner fails against empty disposable PVCs. GREEN: restore one stop-write backup set under one run ID. | Restored benchmark subset and ACL negatives. GitOps workload owner + operator; delete disposable PVCs, then restart original only after evidence. |
| S5 — disposition | Evidence ends in delete, bounded retention, or a separately approved HA proposal. | RED: no default-keep path. GREEN: record exactly one P4 outcome and execute its cleanup or operating ceiling. | Proposal/index closure and credential/PVC inventory. `homelab`; deletion is the default failed-gate rollback. |

### P0 — make the deployment claim honest

Before sync:

1. restore reproducible full GitOps validation; the billing-blocked GitHub job
   is not a pass, while the local server-side dry-run is supporting evidence;
2. publish and sign the custom Cognee image, then pin its immutable GHCR digest
   in the Deployment; a version tag is not a deployable release. Make the
   secret-free package anonymously pullable and prove the pull before sync;
3. run Terraform plan/review for the Cognee LiteLLM key and OpenBao handoff,
   then apply leaf-first only after approval;
4. verify the four non-LiteLLM `lab/cognee` Vault values exist without printing
   them and that ESO can read the Terraform-managed LiteLLM key path;
5. render the Argo application and manifests, confirm immutable images, and
   prove ingress/TLS exposure plus the LAN-only LiteLLM egress path;
6. complete the 18-question source-backed retrieval baseline, then extend it
   with six
   Cognee-only cases covering ACLs, restart persistence, repeated ingestion,
   deletion, and relationship recall;
7. define a synthetic/public fixture capped at 100 documents or `25MiB`,
   containing code-like symbols, history, contradictory revisions, and a
   secret-canary file that must be excluded;
8. record exact API calls, repetitions, scoring, and a LiteLLM request/token
   ceiling before deploying.

**Gate:** full validation passes, signed image digest is pinned, Terraform is
reviewed/applied, secret paths exist, and baseline/fixture review passes. Any
mismatch blocks sync; do not disable access control to make startup succeed.

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
- evaluating or repairing Cognee dashboard feature completeness.

## Rollback

Because the live namespace and Application do not yet exist, pre-sync rollback
is deletion of the unmerged canary manifests. After sync, stop ingestion, retain
only sanitized evidence, delete the Argo application, namespace, and explicitly
identified Cognee PVCs, then revoke the Cognee Vault credentials and LiteLLM
consumer access. Canonical Git sources and the Hermes wiki remain unchanged.

## Next gate

Choose one local next gate: either authorize temporary use of the dedicated
Cognee LiteLLM credential to bind the synthetic ACL/routing scenarios on
`1.4.2`, or wait for a Falkor adapter that supports stable Cognee and rerun the
compatibility seam. After that, return to the existing signed-image, Vault, and
benchmark P0 gates. Do not sync production or ingest private homelab content.

## References

- [Cognee 1.5.3 package metadata](https://pypi.org/project/cognee/1.5.3/)
- [Cognee v1.4.2 to v1.5.3 comparison](https://github.com/topoteretes/cognee/compare/v1.4.2...v1.5.3)
- [SecretSpec project manifest and CLI](https://secretspec.dev/quick-start/)
- [SecretSpec providers](https://secretspec.dev/concepts/providers/)
- [Cognee setup and database guidance](https://docs.cognee.ai/setup-configuration/overview)
- [Cognee security and multi-user isolation](https://docs.cognee.ai/setup-configuration/security)
- [Cognee permissions and provider/handler compatibility](https://docs.cognee.ai/setup-configuration/permissions)
- [Cognee Kuzu dataset handler](https://docs.cognee.ai/core-concepts/multi-user-mode/dataset-database-handlers/existing-dataset-database-handlers/kuzu)
- [Cognee FalkorDB community handler](https://docs.cognee.ai/core-concepts/multi-user-mode/dataset-database-handlers/existing-dataset-database-handlers/falkor)
- [Cognee official Falkor image-registration recipe](https://github.com/topoteretes/cognee-integrations/blob/main/integrations/openclaw/skills/falkor/SKILL.md)
- [Falkor adapter 0.4.0 package metadata](https://pypi.org/project/cognee-community-hybrid-adapter-falkor/0.4.0/)
- [Cognee 1.4.2 dashboard/API mismatch](https://github.com/topoteretes/cognee/issues/4431)
- [FalkorDB persistence guidance](https://docs.falkordb.com/operations/persistence.html)
- [Local repository knowledge and retrieval](2026-08-16-local-repository-knowledge-retrieval.md)
- [Stateful stack and release hardening](2026-07-13-stateful-stack-release-hardening.md)
- [Hermes AgentMemory integration history](2026-06-25-hermes-agentmemory-integration.md)
