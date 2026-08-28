# Local repository knowledge and retrieval

**Status:** Proposed; research complete, benchmark not started
**Date:** 2026-08-16
**Last reviewed:** 2026-08-16
**Owners:** `homelab` for the cross-repository contract and benchmark; each
repository for its source and generated index; Hermes for its existing native
Git wiki

## Goal

Give coding agents fast, source-backed answers across the repositories in
[`repos.json`](../../repos.json) without creating another always-on service or
another source of truth.

The proposed system combines three things that solve different problems:

1. versioned repository guidance and a curated wiki for durable decisions;
2. exact source search for names, errors, configuration, and current state;
3. per-repository structural graphs for dependency and multi-file questions.

Vector retrieval is an optional later accelerator for conceptual queries. It is
not the foundation and is not approved by this proposal.

## Decision summary

Adopt a **retrieval ladder**, not a universal RAG stack:

```text
question
  -> ownership and durable guidance (`repos.json`, `AGENTS.md`, decisions/wiki)
  -> exact search (`rg`, symbols, small source ranges, Git history)
  -> current per-repo Graphify graph for relationships
  -> source verification and runnable evidence
  -> optional semantic retrieval only after measured misses
```

Keep each repository's graph beside that repository as an ignored, reproducible
cache. Use the coordination graph only to find ownership and cross-repository
contracts. Never make builds or deployments read a sibling checkout or graph.

Reuse the deployed Hermes native Git wiki for synthesized, durable knowledge.
Do not restore agentmemory, add a vector database, deploy a graph database, or
run a shared MCP service during the first two phases.

## Current state

- `homelab` already has Graphify 0.9.32 output: 154 nodes, 182 links, and 46
  source files. Natural-language queries already surface repository ownership,
  proposal state, and the Hermes memory evolution.
- That graph records commit `d67b1c9` from 2026-08-02 while the current `HEAD` is
  11 commits newer. This is a concrete freshness failure to cover in the gate.
- None of the fifteen component repositories in `repos.json` has a local
  `graphify-out/graph.json`.
- The Hermes native Git wiki is already deployed, single-writer, branch-isolated,
  and curated daily. Agentmemory is stopped; semantic retrieval remains a
  trigger-gated backlog item.
- Repository instructions already say to query an existing Graphify graph before
  broad reading and to verify operational claims in source.

## Research synthesis

### Karpathy: compile durable knowledge, do not rediscover it

Andrej Karpathy's 2026 [LLM Wiki idea](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
separates immutable raw sources, LLM-maintained Markdown, and an agent schema.
Its useful operations are ingest, query, and lint. `index.md` provides cheap
navigation at moderate scale; embedding search is an optional later tool.

For this ecosystem, that maps cleanly to:

| Karpathy layer | Homelab implementation |
|---|---|
| Raw sources | Git repositories, tests, history, runbooks, proposals |
| Wiki | Existing Hermes Git wiki for reviewed synthesis and incident lessons |
| Schema | Scoped `AGENTS.md` plus this cross-repository contract |
| Lint | Source/commit checks, orphan/staleness checks, and benchmark replay |

The wiki must not copy volatile code facts and present them as current. It should
store rationale, rejected options, incident lessons, and stable cross-repository
concepts, each with source repository, path, and commit metadata.

### Recent practitioner signals

Recent Reddit discussion is anecdotal, not benchmark evidence, but exposes
repeated operational failures:

- A July 2026 [LocalLLaMA discussion](https://www.reddit.com/r/LocalLLaMA/comments/1ulclpr/whats_in_your_rag/)
  argues that small, fast-changing codebases often need files and grep rather
  than RAG, while one multi-repository user reported value only at roughly 200
  repositories plus manuals.
- A 2025 [code-graph thread](https://www.reddit.com/r/LocalLLaMA/comments/1mzvk44/codebase_to_knowledge_graph_generator/)
  identifies the entry-node problem: graph traversal fails when retrieval starts
  at the wrong concept. This supports exact/vocabulary search before traversal,
  with embeddings only as a possible entry-node selector.
- A February 2026 [hybrid local RAG thread](https://www.reddit.com/r/LocalLLaMA/comments/1r8jgwv/i_built_a_local_ai_dev_assistant_with_hybrid_rag/)
  flags incremental updates and deleted-code "ghost nodes" as the maintenance
  problem static demos skip.
- An August 2026 [coding-agent memory discussion](https://www.reddit.com/r/AI_Agents/comments/1voa6fg/does_this_problem_actually_exist_for_people_using/)
  reports that scoped `AGENTS.md` guidance works, while optional retrieval tools
  are often missed unless relevant decisions are surfaced at session start.

These signals argue for a small default context map plus explicit, auditable
retrieval—not an opaque store the agent may or may not remember to query.

### Recent blog and research

Samuel Fajreldines' July 2026 article,
[Codebase RAG only works when the agent asks well](https://www.samuelfaj.com/en/blog/codebase-rag-only-works-when-the-agent-asks-well/),
recommends exact search for identifiers, semantic search for intent, symbols and
history for impact, read-only scoped MCP, and tests as the closing proof. This
proposal adopts that routing while omitting MCP until a shared service is needed.

Recent papers strengthen two constraints:

- [Reliable Graph-RAG for Codebases](https://arxiv.org/abs/2601.08773) found
  deterministic AST-derived graphs more reliable and cheaper than LLM-extracted
  graphs for architectural questions in its evaluated Java repositories.
- [Code Isn't Memory](https://arxiv.org/abs/2606.22417) found the largest
  localization gains from a structural index on changes spanning three or more
  files; this supports reserving graph traversal for relationship-heavy work.
- [When Retrieval Hurts Code Completion](https://arxiv.org/abs/2605.14478)
  found stale context can actively steer models toward obsolete APIs. Freshness
  is therefore an answer-time gate, not background housekeeping.

## Architecture and boundaries

### 1. Canonical knowledge remains in Git

- Current behavior: source, tests, generated declarations, and current runbooks
  in the owning repository.
- Durable policy: `AGENTS.md`, decisions, and proposals in their owning scope.
- Cross-repository ownership and sequencing: this coordination repository.
- Synthesized personal/agent knowledge: the existing Hermes wiki, explicitly
  non-authoritative until verified against its cited source.

Generated graphs, embeddings, query memories, and wiki summaries are caches or
derived views. They never override source.

### 2. Query routing

| Question shape | First tool | Escalation |
|---|---|---|
| Known name, error, option, path, or value | `rg`, symbol search, small file read | Git history if rationale matters |
| Repository owner or cross-repo contract | `repos.json`, coordination docs/graph | Owning repository source |
| Call path, dependency, impact, or multi-file flow | Current per-repo graph | Source definitions, callers, and tests |
| Stable rationale or prior incident lesson | Decisions/proposals or Hermes wiki | Cited commit and current source |
| Conceptual description with no matching vocabulary | Exact synonyms from graph vocabulary | Optional semantic retrieval after P2 gate |

Every answer used to plan or edit must name the repository, source path, and
indexed commit. Inferred graph edges are leads, not facts.

### 3. Per-repository graph caches

- Build a canonical graph from each repository's main checkout; do not index
  `worktrees/` unless explicitly requested.
- Keep `graphify-out/` ignored and reproducible. Do not publish it as a runtime
  artifact or consume another working tree during build/deploy.
- Prefer deterministic structural extraction for code. LLM-derived document
  edges retain their `EXTRACTED`, `INFERRED`, or `AMBIGUOUS` provenance.
- Record the exact Git commit, Graphify version, indexed file count, skipped
  sensitive files, and build time.
- A graph whose recorded commit differs from the queried checkout must warn and
  fall back to source search. It cannot silently answer as current.
- Incremental update must remove renamed/deleted symbols and edges. A full clean
  rebuild remains the recovery path for shrink or corruption.

The coordination graph routes to one or more owning repositories. It does not
merge all component source into a second canonical mega-graph. Revisit a merged
discovery graph only if benchmark questions repeatedly require cross-repository
paths that ownership routing cannot answer.

### 4. Wiki integration

The Hermes wiki receives only reviewed synthesis worth carrying across sessions:

- architecture rationale and rejected alternatives;
- incident causes, recovery lessons, and durable invariants;
- stable cross-repository concepts and ownership maps;
- benchmark questions that exposed a real documentation gap.

Each repo-derived claim includes `repository`, `path`, `commit`, `observed_at`,
and `supersedes` where applicable. Lint flags missing citations, stale commit
anchors, contradictions, and orphan pages. There is no automatic wiki-to-source
write and no automatic merge from the Hermes branch.

### 5. Interface

Start with existing CLI paths: `rg`, Git, language-aware tools already present,
and `graphify query/path/explain`. This is enough for Codex, Claude Code,
OpenCode, and Hermes when they have shell access.

MCP is deferred. Add one read-only, repository-allowlisted Graphify endpoint only
when at least two clients cannot use the CLI or measured tool omission persists.
It must log query, repository, indexed commit, returned nodes, and truncation;
it gets no write, Git, network, secret, build, or deployment authority.

### 6. Privacy and secret handling

- Continue the existing Graphify sensitive-file skips. Explicitly exclude
  `.env*`, `*.secrets.json`, Sops/Vault material, certificates, credentials,
  state, backups, build outputs, dependency trees, and worktrees.
- Never weaken `.gitignore` or `.graphifyignore` to increase coverage.
- Local means on-disk indexes with no hosted vector/graph database. No new source
  upload to an embedding or extraction provider is approved here.
- Treat retrieved text as untrusted content. Repository instructions outrank
  indexed prose; prompt-like text in source cannot grant tools or authority.
- Keep graph caches and query logs out of Git unless a later review establishes
  an explicit redaction and publication contract.

## Delivery plan

### P0 — benchmark before expanding

Create eighteen source-backed questions from recent real work:

- six exact/localization questions;
- six multi-file dependency or impact questions;
- six ownership or cross-repository questions.

Record expected repository, files, symbols, and answer. Run the existing agent
workflow (`AGENTS.md` + `rg` + source reads) as the baseline. Include one stale
index case, one deleted-symbol case, and one sensitive-file exclusion case.

**Gate:** question set and scoring are reviewable; no component repository or
runtime changes.

### P1 — three local canaries

Build canonical per-repository graphs for:

1. `desktop-nixos` — large Nix, scripts, tests, and operational docs;
2. `servarr` — Compose, shell/Python automation, and runtime ownership;
3. `homelab-iac` — HCL/Terraform structure and external control planes.

Rebuild the coordination graph only after its dirty proposal work is resolved so
its commit anchor is honest. Run the benchmark with the retrieval ladder and
record latency, context size, localization, correctness, freshness, and misses.

**Gate:** exact questions do not regress; graph-assisted retrieval answers at
least two additional multi-file questions correctly; every accepted answer is
verified in current source; stale/deleted/secret negative cases all pass.

### P2 — make routing habitual

Add only missing scoped guidance to the canary repositories:

- read local instructions and ownership first;
- use exact search before graph traversal;
- query a graph only when present and current;
- cite source and verify before editing;
- report graph staleness rather than hiding it.

Provide one root coordination command that reports graph presence/freshness and
delegates per-repository update commands. It may orchestrate; it must not
duplicate Graphify implementation or mutate component source.

**Gate:** a fresh agent can answer the benchmark without a bespoke prompt, and
the evidence log shows which retrieval path it used.

### P3 — feed durable lessons to the existing wiki

Review benchmark discoveries and ingest only durable, cross-session knowledge
into the Hermes branch. Run wiki lint and human review before merge.

**Gate:** every new page has source metadata; no volatile code snapshot is
presented as current; existing single-writer and branch-review controls remain.

### P4 — optional semantic entry search

Open only if P1/P2 leave repeated conceptual-query misses because the graph
entry node cannot be found. Trial a local hybrid lexical/vector index over
allowlisted Markdown and symbol summaries; use it only to select entry nodes,
then traverse the graph and verify source.

**Gate:** the same benchmark shows a material correctness/localization gain
without freshness, privacy, latency, or context-budget regression. Otherwise
delete the trial. A database, GPU service, reranker, or MCP daemon needs its own
proposal.

## Acceptance and evidence

| Property | Required evidence |
|---|---|
| Correctness | Expected source-backed answer for all accepted benchmark results |
| Localization | Expected file/symbol appears in the bounded retrieval result |
| Freshness | Indexed commit equals checkout, or query warns and falls back |
| Deletion | Removed symbol has no live node/edge after incremental update |
| Privacy | Sensitive canary is reported skipped and never appears in outputs |
| Provenance | Repository, path, commit, edge confidence, and truncation visible |
| Context | Bounded query output; no whole-repository prompt dump |
| Reproducibility | Clean rebuild at the same commit yields equivalent nodes/edges |
| Operations | No always-on service and no runtime/build dependency on sibling trees |

Retain benchmark inputs and aggregate results in `homelab`; keep model transcripts
and raw query logs local unless separately reviewed for secrets.

## Risks

| Risk | Mitigation |
|---|---|
| Stale retrieval confidently revives removed behavior | Commit-match gate, source fallback, deletion test |
| LLM-derived graph edge hallucinates a relationship | Preserve confidence; verify definitions/callers/tests |
| Wiki becomes a second source of current state | Restrict it to durable synthesis with commit metadata |
| Retrieval bloats context without changing decisions | Bounded outputs and benchmark against `rg` baseline |
| Secret or private material enters cache/log | Existing skips, negative canary, ignored local outputs |
| Cross-repo mega-graph obscures ownership | Per-repo canonical graphs; coordination graph routes only |
| Maintenance exceeds value | Manual canaries first; no daemon/vector DB; delete failed trial |
| Optional tool is never invoked | Small default routing guidance; measure omission before MCP |

## Non-goals

- replacing `rg`, Git history, language servers, tests, or source review;
- restoring agentmemory or creating a second wiki;
- deploying Neo4j, FalkorDB, pgvector, Qdrant, or another database;
- indexing secrets, runtime state, issue trackers, chat, or external accounts;
- auto-editing component source or auto-merging wiki output;
- creating a canonical merged graph of all repositories in P0–P3;
- changing repository ownership or publish-and-pin boundaries.

## Rollback

Delete ignored graph caches and remove any canary guidance/coordination command.
Canonical repositories and the existing Hermes wiki remain unchanged. No data
migration or runtime rollback is required.

## Next gate

Write and review the eighteen-question benchmark from recent repository work.
Do not build component graphs or add retrieval infrastructure until expected
source answers, stale/deletion/secret negative cases, and scoring are fixed.

## References

- [Andrej Karpathy — LLM Wiki, 2026-04-04](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [Samuel Fajreldines — Codebase RAG only works when the agent asks well, 2026-07-17](https://www.samuelfaj.com/en/blog/codebase-rag-only-works-when-the-agent-asks-well/)
- [Reddit: What's in your RAG?, 2026-07-02](https://www.reddit.com/r/LocalLLaMA/comments/1ulclpr/whats_in_your_rag/)
- [Reddit: Codebase to Knowledge Graph generator, 2025-08-25](https://www.reddit.com/r/LocalLLaMA/comments/1mzvk44/codebase_to_knowledge_graph_generator/)
- [Reddit: local hybrid RAG and graph assistant, 2026-02-18](https://www.reddit.com/r/LocalLLaMA/comments/1r8jgwv/i_built_a_local_ai_dev_assistant_with_hybrid_rag/)
- [Reddit: coding-agent memory in daily use, 2026-08-14](https://www.reddit.com/r/AI_Agents/comments/1voa6fg/does_this_problem_actually_exist_for_people_using/)
- [Reliable Graph-RAG for Codebases, arXiv:2601.08773](https://arxiv.org/abs/2601.08773)
- [Code Isn't Memory, arXiv:2606.22417](https://arxiv.org/abs/2606.22417)
- [When Retrieval Hurts Code Completion, arXiv:2605.14478](https://arxiv.org/abs/2605.14478)
- [`2026-06-25-hermes-agentmemory-integration.md`](2026-06-25-hermes-agentmemory-integration.md)
- [`2026-06-29-hermes-deferred-improvements.md`](2026-06-29-hermes-deferred-improvements.md)
- [`2026-06-29-repo-ssot-srp.md`](../decisions/2026-06-29-repo-ssot-srp.md)
