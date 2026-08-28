# Cross-harness coding-agent benchmark matrix

**Status:** Deterministic C0 plan and both infrastructure canaries implemented; fixed C0 awaits network-policy approval
**Date:** 2026-08-21
**Owners:** `homelab-iac` for GitHub repository creation; `agent-evals` for the
runner, adapters, manifests, tests, and raw local evidence; `homelab` for the
cross-repository contract and sanitized aggregate evidence

## Destination

Produce a reproducible, paired answer to one question:

> With the model, reasoning level, task, environment, and limits held fixed,
> how much does the coding-agent harness change correctness, reliability,
> latency, token use, and API-equivalent cost?

The first cohort compares Prime Agent and native Codex using
`openai-codex/gpt-5.6-luna` with `xhigh` reasoning on Terminal-Bench 2 and
SWE-bench Verified. The full cohort is gated behind a smaller paired pilot.
Execution uses existing subscriptions or local models and local compute; it
must not issue metered API requests. Reported dollar values are shadow API
estimates, not incurred charges.
The owning behavior contract is
[`agent-benchmark-matrix.feature`](https://github.com/ErikBPF/agent-evals/blob/main/features/agent-benchmark-matrix.feature).
Its manifest, pricing, matrix, failure-taxonomy, exact C0 planning, append-only
resume scheduling, and adapter scenarios have stdlib bindings. Translating a
scheduled cell into a live Harbor command and aggregating paired results remain.
`homelab-iac` PR 72 is merged and now manages the private repository. The first
Prime Agent `0.7.4` and Codex `0.148.0` concurrency-1 infrastructure canaries
both passed with reward `1.0`, exact model/reasoning metadata, shadow API cost,
and clean exact-value secret scans. They remain outside C0 because the task used
Harbor's public network policy. Implementation is at `agent-evals` commit
`bc034af` with CI and the repository secret scan green.

This is a harness comparison, not a new model leaderboard. A separate external
context matrix preserves official model-plus-harness results and fixed-harness
model baselines. A later local cohort may add another harness or model only
without changing the identity of an accepted cohort.

## Motivation and evidence

The 2026-08-20/21 Prime Agent probe exposed benchmark-infrastructure failures
before it produced useful full-suite evidence:

- one `terminal-bench/regex-log` trial passed with reward `1.0` on Prime Agent
  `0.7.4-beta.531.1.c75a637`, Luna, and `xhigh`;
- the first full run coupled Harbor retry behavior to a rootless-Podman
  permission failure and canceled sibling trials;
- the next run lost local state because its job and adapter lived under `/tmp`;
- the persistent run then recorded setup and environment timeouts as apparent
  benchmark failures while four trials installed the harness concurrently;
- mounting authentication beneath the agent artifact directory copied a live
  token into collected output until the layout was corrected.

These are harness-runner defects, not evidence about task capability. The new
contract must make infrastructure validity a gate rather than silently turning
it into reward `0`.

Harbor already provides a common task, dataset, agent, environment, trial, and
job model, built-in agent integrations, and registered Terminal-Bench and
SWE-bench datasets. Reuse it rather than creating another evaluation engine.
Harbor lists Terminal-Bench 2 as 89 tasks and SWE-bench Verified as 500 tasks;
the initially proposed two-harness full matrix contained 1,178 primary trials.
The accepted scope caps SWE-bench Verified at C1, reducing C2 to 178
Terminal-Bench primary trials.

## Accepted minimum cohort

### Fixed dimensions

| Dimension | Cohort value |
|---|---|
| Execution framework | One pinned Harbor release |
| Harnesses | Prime Agent; native Codex CLI |
| Model/provider | `openai-codex/gpt-5.6-luna` |
| Reasoning | Requested and observed `xhigh` |
| Benchmarks | `terminal-bench/terminal-bench-2`; `swe-bench/swe-bench-verified` |
| Task identity | Registry dataset version plus each resolved task digest |
| Environment | Same Harbor environment provider and resource policy within each paired benchmark cohort |
| Reward | Benchmark-native verifier reward; never a pooled cross-benchmark mean |

Prime Agent's delegation and Codex's native loop are part of the harnesses being
measured. They are not normalized away. Prompt text, model, task digest,
reasoning request, timeout, network policy, and environment remain fixed.

OpenCode, Claude Code, Mini-SWE-Agent, DeepSeek Harness, and TinyCoder are
expansion candidates, not members of the first cohort. Add one only when it can
use the same model/provider contract or place it in an explicitly cross-model
cohort. The existing Orion benchmark already compares Prime Agent, DeepSeek
Harness, and TinyCoder against one local coding fixture; it remains useful
evidence but does not substitute for independent benchmark suites.

### Benchmark roles

| Benchmark | Capability represented | Initial use |
|---|---|---|
| Terminal-Bench 2 | General terminal operation, building, debugging, and system tasks | Preserve the 89-task dataset used by the initial probe; do not silently replace it with the moving Terminal-Bench dataset |
| SWE-bench Verified | Repository issue resolution against human-validated problem/test pairs | Add a materially different software-engineering workload, not another terminal-task sample |

Terminal-Bench's current moving dataset is separate from Terminal-Bench 2 and
includes GPU and multi-container tasks. Any future migration is a new cohort.
SWE-bench Verified's native harness documents substantial x86_64 storage,
memory, and CPU needs; resource compatibility is an environment gate, not an
afterthought.

## Official-result context matrix

Official benchmark results answer two different questions that must remain
separate:

| Evidence class | Fixed dimensions | Question it can answer |
|---|---|---|
| Fixed-harness model baseline | benchmark, tasks, harness release, and published policy | How do models compare inside one official scaffold? |
| Mixed-harness system result | benchmark and submission policy | How did a submitted model-plus-harness system perform? |
| Local paired cohort | benchmark task digests, model, reasoning, environment, limits, and run window | How much did Prime Agent versus native Codex change the result here? |

The external matrix stores a row as a system result, never as a model-only
score. Each row requires benchmark name/version, task count or task-set
identity, score and uncertainty when published, model display and provider
identity, harness/agent and version when published, attempt policy, submission
date, source URL, official verification state, trajectory availability, and a
source-quality advisory. Missing fields stay missing.

### Canonical benchmark x model x harness report

Every local or official observation uses one row shape:

| Benchmark/version | Model | Harness/version | Native metric | Official | Ours | Delta | Local coverage | Comparison |
|---|---|---|---|---:|---:|---:|---:|---|
| Terminal-Bench 2.0 | `openai-codex/gpt-5.6-luna` | Prime Agent, pinned | accuracy | N/A | pending | N/A | 0/89 | local-only until an exact official row exists |
| Terminal-Bench 2.0 | `openai-codex/gpt-5.6-luna` | Codex CLI, pinned | accuracy | N/A | pending | N/A | 0/89 | local-only until an exact official row exists |
| SWE-bench Verified | `openai-codex/gpt-5.6-luna` | Prime Agent, pinned | percent resolved | N/A | pending | N/A | 0/500 | local historical sensitivity |
| SWE-bench Verified | `openai-codex/gpt-5.6-luna` | Codex CLI, pinned | percent resolved | N/A | pending | N/A | 0/500 | local historical sensitivity |

`Official` is populated only for the same benchmark version, exact model
identity, and harness identity. `Ours` always shows its completed/valid task
coverage. A numeric `Delta` requires the same task population and compatible
official attempt, resource, timeout, and scoring policies. Otherwise the two
scores may appear side by side with `Delta = N/A` and an explicit reason.

Official rows using another model or harness remain in the context matrix, not
in the `Official` cell for our row. In particular, a published GPT-5.5 Codex
CLI result is not the official value for Luna Codex CLI.

### Benchmark registry and expansion gate

The runner treats benchmarks as rows in a registry, not report columns baked
into code:

| Benchmark key | Harbor dataset | Official result source | Metric | Initial scope | Signal state |
|---|---|---|---|---|---|
| `terminal-bench@2.0` | `terminal-bench/terminal-bench-2` | Terminal-Bench 2.0 leaderboard | accuracy | C0, C1, C2 | active official system benchmark |
| `swe-bench@verified` | `swe-bench/swe-bench-verified` | SWE-bench Verified leaderboards | percent resolved | C0 and C1 only | active official table; disputed frontier signal |

A later benchmark joins only when it has an immutable dataset/version, native
verifier and metric, official result source or an explicit `none`, runnable
Harbor dataset/environment, task and spend estimates, and a source-quality
advisory. Adding it creates a new cohort; it does not change completed reports.
No generic benchmark plugin framework is required beyond Harbor's existing
dataset and verifier interfaces.

### Survey snapshot — 2026-08-21

This small snapshot validates the shape; it is not a vendored leaderboard and
must not be treated as current after its source date.

| Benchmark/view | Model | Harness/agent | Official result | Interpretation |
|---|---|---|---|---|
| Terminal-Bench 2.0 system | GPT-5.5 | NexAU-AHE | 84.7% +/- 2.1 | Same model family appears with materially different harness results |
| Terminal-Bench 2.0 system | GPT-5.5 | Codex CLI | 82.2% +/- 2.2 | Official native-Codex reference, not a Luna result |
| Terminal-Bench 2.0 system | GPT-5.5 | clnkr | 66.1% +/- 2.5 | Observed GPT-5.5 harness envelope spans 18.6 points; not a causal estimate |
| Terminal-Bench 2.0 system | GPT-5.2 | Droid / Codex CLI / Mux / Terminus 2 | 64.9% / 62.9% / 60.7% / 54.0% | Same-model multi-harness prioritization signal |
| SWE-bench Verified bash-only | Claude 4.5 Opus high | mini-SWE-agent 2.0.0 | 76.8% | Fixed-harness model baseline |
| SWE-bench Verified bash-only | Gemini 3 Flash high | mini-SWE-agent 2.0.0 | 75.8% | Fixed-harness model baseline |
| SWE-bench Verified bash-only | MiniMax M2.5 high | mini-SWE-agent 2.0.0 | 75.8% | Fixed-harness model baseline |
| SWE-bench Verified bash-only | GPT-5 Mini | mini-SWE-agent 2.0.0 | 56.2% | Fixed-harness model baseline; not Luna |

Terminal-Bench 2.0 submissions use Harbor, forbid resource/timeout overrides,
and require at least five trials per task. Its leaderboard is therefore the
best initial official system matrix for our Harbor cohort. Differences between
two public rows remain observational because prompts, agent versions, reasoning,
provider behavior, and dates may differ.

SWE-bench's bash-only view intentionally fixes mini-SWE-agent to compare models,
while its full leaderboard compares arbitrary systems. Releases 1.x and 2.x are
not necessarily comparable. The official SWE-bench project still publishes the
Verified leaderboard, but OpenAI, its co-creator, stopped using Verified for
frontier reporting in February 2026 because of task defects and contamination.
In July 2026 OpenAI also retracted its interim recommendation of SWE-Bench Pro
after finding widespread task-quality problems. The matrix must carry those
advisories instead of silently blessing either score as capability truth.

### How the local harnesses help

1. **Fill missing controlled cells.** Luna has no official row in the surveyed
   Terminal-Bench 2.0 or SWE-bench Verified tables. Prime Agent and native Codex
   can create a same-model, same-task, same-environment pair without aliasing
   Luna to another GPT model.
2. **Measure harness sensitivity.** Run both harnesses on every selected task;
   report paired wins/ties/losses and score delta beside, not merged into, the
   official same-model envelope.
3. **Diagnose score gaps.** Compare failure classes and reviewed trajectories
   for tasks where the local pair disagrees or both diverge from a reproducible
   official row. Do not infer a cause from aggregate score alone.
4. **Prioritize later cohorts.** Prefer model/benchmark cells with an official
   fixed-harness baseline and multiple official system submissions. Add a model
   only when access, exact identity, and budget are approved.
5. **Audit benchmark signal.** Repeated cross-harness disagreement identifies
   tasks for human review; it does not authorize changing the upstream verifier
   or excluding a task after seeing our score.

The first implementation needs only a reviewed source snapshot in the cohort
manifest and aggregate. A recurring importer or scraper is deferred until two
manual refreshes demonstrate that automation would remove real work.

## Evaluation stages and gates

### C0 — adapter and infrastructure canary

Select and pin three tasks from each benchmark: one known-solvable task, one
representative task, and one environment-stress task. Run both harnesses on all
six task digests: 12 primary trials.

Gate:

- all 12 environments start and all harnesses install or load;
- setup, auth, agent, verifier, and artifact phases are classified separately;
- no secret pattern appears in commands, logs, trajectories, or artifacts;
- interruption and resume preserve completed cells and schedule only missing
  cells in fresh trial directories;
- no full benchmark starts while any infrastructure error remains.

### C1 — paired stratified pilot

Select twelve fixed task digests from each benchmark across available
difficulty, language/repository, category, and environment strata. Run one
trial for each harness-task cell: 48 primary trials.

For task pairs with different rewards, or for a cell rerun after a corrected
infrastructure fault, run two additional independent repetitions per harness
within the 144-trial C1 ceiling. Do not selectively repeat only the losing
harness.

Gate:

- zero unresolved infrastructure errors;
- every comparison has both harness results for the same task digest;
- benchmark-native rewards, paired win/tie/loss, latency, tokens, cache tokens,
  actual incremental spend, shadow API cost, and failure classes are present;
- each local aggregate links comparable official rows without merging them into
  the local denominator;
- the result answers a harness decision or the experiment stops as
  inconclusive;
- the accepted cohort manifest remains unchanged before C2.

### C2 — full Terminal-Bench paired cohort

Run the 89 Terminal-Bench 2 tasks once per harness: 178 primary trials. SWE-bench
Verified stops at its accepted twelve-task-per-harness C1 pilot. Repetitions are
an explicit follow-up cohort, not an unbounded automatic retry policy.

Do not pool Terminal-Bench and SWE-bench rewards into a single mean. Report for
each benchmark:

- mean native reward/pass rate with task count;
- paired wins, ties, and losses;
- infrastructure-error rate excluded from the capability denominator and shown
  separately;
- agent-error and timeout rates included and labeled;
- wall-clock latency distribution;
- input, cache, and output tokens plus reported cost;
- exact missing/invalid cells.

Alongside each benchmark report, show official context rows in three groups:
same model plus same harness when available, same model plus other harnesses,
and fixed-harness models. Never rank a local partial cohort against a full
official cohort.

### C3 — deferred

No official-policy reproduction is approved for the initial program. A future
C3 needs a new accepted cohort and trial ceiling. It remains subject to the
subscription/local-only and zero-incremental-spend boundaries.

## Validity and reproducibility contract

### Immutable cohort manifest

Before the first trial, record:

- Harbor version and lockfile;
- harness names, exact versions or commits, adapter digest, and install artifact
  digest;
- provider, model, reasoning request, and observed model identity;
- dataset references and resolved task digests;
- environment provider, image digests, architecture, resources, timeouts,
  network policy, and concurrency;
- prompt template and any harness-specific flags;
- official source URL, retrieval date, source revision when available, and
  comparison class for every contextual result;
- benchmark registry key, native metric, signal state, and official-policy
  compatibility reason;
- a price-book digest with provider, exact model, pricing mode, context band,
  token/tool units, rates, source URL, and retrieval date;
- start time, cohort ID, zero incremental-spend ceiling, and stage trial ceiling.

Changing any fixed field creates a new cohort. A resume may fill missing cells;
it may not rewrite completed evidence.

### Failure taxonomy

| Failure | Treatment |
|---|---|
| Dataset resolution, image pull/build, environment start, harness setup, credential injection, artifact collection | Infrastructure-invalid; not reward `0`; fix root cause and create a fresh trial ID |
| Harness process exit after successful setup, agent execution timeout, malformed agent output | Harness outcome; retain and report |
| Benchmark verifier returns reward `0` | Capability outcome; retain and report |
| Verifier cannot start or cannot emit its declared metric | Infrastructure-invalid; retain diagnostics and rerun only after correction |
| User/system interruption | Preserve immutable completed cells; resume missing cells only |

Automatic same-directory retry is rejected. The observed Harbor/rootless-Podman
failure showed that retrying into a UID-mapped artifact tree can abort unrelated
trials. A retry is a new trial directory linked to the original invalid cell.

### Harness packaging

No full cohort downloads and installs a moving harness separately inside every
task. Resolve each harness once, pin its artifact, verify its version, and reuse
that artifact. Network installation belongs to a preparation gate. This removes
setup latency from the measured agent phase and avoids parallel cold-start
timeouts.

### Scheduling

- calibrate concurrency in C0; do not choose it only from host CPU count because
  Prime Agent can create internal model concurrency;
- interleave harness order across task pairs so provider load and cache warmth
  do not consistently favor one harness;
- apply one concurrency group and rate policy to the paired cohort;
- use one environment provider per benchmark cohort; a local subset and hosted
  full run are separate cohorts;
- stop cleanly at the trial ceiling or zero-spend boundary and keep partial evidence.

### Actual and shadow cost

Keep two cost fields and never add them together:

- `actual_incremental_spend_usd`: `0.00` for accepted subscription/local runs;
  any path that would incur metered model API or hosted-environment spend is
  rejected before launch;
- `shadow_api_cost_usd`: the API-equivalent estimate from observed usage and a
  dated, exact-model price book.

For GPT-5.6 Luna, the initial OpenAI model-page price snapshot retrieved on
2026-08-21 is $0.20 per million uncached input tokens, $0.02 per million cached
input tokens, and $1.20 per million output tokens. Cache writes cost 1.25 times
the uncached input rate. Requests above 272K input tokens use the documented 2x
input and 1.5x output multipliers for the full request. Store the rates and
source in the cohort; never recompute historical results from a newer price.

The estimator consumes disjoint uncached-input, cached-input, cache-write,
output, and billed-tool units. Prime Agent totals include all delegated child
usage; Codex totals include every model call in the trial. If usage categories
overlap, child usage is missing, or no exact public price exists for a local
model, shadow cost is `N/A` with a reason rather than a guessed value.

Report total shadow cost, median and p95 per valid task, and cost per solved task
for each benchmark-model-harness cell. A zero-solve cell reports cost per solve
as `N/A`. Do not pool cost-efficiency across benchmarks.

## Evidence and retention

Retain in `homelab` only the reviewed cohort manifest, aggregate result, paired
task table, failure summary, and decision. Raw trajectories, prompts containing
repository content, agent session state, and credentials remain ignored local
artifacts unless separately reviewed.

Every aggregate result links to its task digests and immutable local/raw evidence
location. Publishing or uploading to Harbor Hub is a separate authorization.

Authentication uses an ephemeral file/credential mount, never a token-valued
environment variable. The agent configuration directory must be outside the
collected artifact tree. Delete the handoff after the runtime receives it and
scan all readable and UID-mapped artifacts for token patterns before declaring
cleanup complete.

## Decision map

### Destination and actors

- **Operator:** can start, stop, resume, and diagnose a cohort without corrupting
  paired evidence or leaking credentials.
- **Model/harness evaluator:** can attribute a result to the harness rather than
  model, task, environment, or runner drift.
- **Repository maintainer:** receives a bounded recommendation with exact
  evidence and no new production dependency.

### Settled decisions

| Decision | Evidence and consequence |
|---|---|
| Harbor is the common execution layer | It already defines agents, datasets, environments, trials, jobs, custom agents, and both initial datasets; no new engine |
| First comparison fixes Luna/xhigh | Current user goal and successful Prime Agent smoke; isolates harness effect |
| Prime Agent and native Codex form the minimum harness set | Both can use the user's Codex subscription path and same model; two harnesses satisfy the first comparison without cross-model confounding |
| Terminal-Bench 2 and SWE-bench Verified form the minimum benchmark set | 89 terminal tasks plus 500 human-validated repository issues cover distinct capabilities |
| Pilot precedes full matrix | Prior failures prove infrastructure validity before the accepted 178-trial Terminal-Bench C2 |
| Infrastructure-invalid is not capability failure | Setup/environment defects otherwise create false reward `0` evidence |
| Results remain benchmark-specific | Reward scales and task populations are not interchangeable |
| Official scores remain model-plus-harness rows | Public leaderboards mix scaffolds; dropping harness identity manufactures a model claim |
| External and local evidence remain separate | Official rows provide context; only the paired cohort isolates our harness variable |
| No live leaderboard scraper in the first slice | A dated reviewed snapshot meets the decision need without a new service |
| One canonical row spans all benchmarks | Benchmark, model, and harness are dimensions; native metrics remain unpooled |
| Direct delta needs official-policy compatibility | Side-by-side display is allowed with coverage; incompatible cells receive no numeric delta |
| Official-policy reproduction is opt-in | Matching policies such as Terminal-Bench's five attempts would otherwise multiply cost across the matrix |
| Execution is subscription/local only | User-selected boundary; actual incremental model/API and hosted-environment spend is zero |
| API prices are a shadow metric | Enables cost comparison without changing the execution provider or incurring API charges |
| Price books are exact and immutable | Exact model, pricing mode, context band, rates, source, and date prevent historical drift |
| `homelab-iac` creates `agent-evals` | User-approved external-control-plane owner; create a private least-privilege repository before runner implementation |
| `agent-evals` owns the runner | Neutral owner prevents harness-specific flakes and Servarr's Orion runner from gaining cross-benchmark responsibility |
| SWE-bench Verified stops at C1 | Twelve tasks per harness retain bounded historical sensitivity evidence without spending on all 500 disputed tasks |
| Initial C3 is disabled | Official-policy repetition is deferred until C1/C2 evidence justifies the multiplied trial count |

### Dependencies

```text
GitHub IaC creates private agent-evals
  -> homelab registers the checkout
  -> agent-evals binds the feature and pins harness artifacts
  -> C0 infrastructure validity
  -> C1 paired pilot
  -> C2 full Terminal-Bench 2 cohort
  -> reviewed recommendation
```

### Open questions

None block implementation. New benchmark/model/harness cohorts require their
own accepted manifest and ceilings.

### Fog

- Whether every Prime Agent and Codex task can use identical network policy
  without harming benchmark validity.
- Whether provider-side concurrency limits make four local task slots unfair or
  unstable after Prime Agent delegation.
- Which exact stratified task IDs best represent each dataset; resolve from
  pinned metadata during the manifest slice before any paid-in-quota execution.
- Whether an official result for Luna appears under a different exact provider
  identity; do not use family-name inference to fill it.
- Which newer repository benchmark has enough independent task-quality evidence
  to replace SWE-bench Verified for a future frontier-capability cohort.

### Frontier

Start Slice 0 in an isolated clean `homelab-iac` worktree. Review the exact
GitHub plan before apply; then initialize and register `agent-evals` leaf-first.

## Party ledger

- **Product/domain:** wanted a decision-useful comparison, not a giant
  leaderboard. Favored two harnesses and two complementary benchmarks first.
- **Developer/architect:** required fixed model/task/environment identity,
  immutable cohort manifests, and a neutral runner owner. Rejected placing a
  cross-harness runner in a harness-specific flake.
- **Tester/operator:** required canary and pilot gates, paired completeness,
  fresh-directory reruns, resumability, and explicit infrastructure taxonomy.
- **CodeHero — security/reliability/operations:** required ephemeral credentials,
  no raw transcript publication, pinned artifacts, bounded concurrency, and
  cleanup evidence. Security is applicable; accessibility is not.
- **Material disagreement:** run full datasets immediately versus stratify first.
  The observed false failures and 1,178-trial size resolved this in favor of a
  mandatory pilot.
- **Official-results extension — product/evaluator:** wanted a model matrix for
  orientation, but rejected presenting system submissions as model-only facts.
  Favored a fixed-harness model view beside a mixed-harness system view.
- **Official-results extension — architect/operator:** favored a reviewed dated
  snapshot over a scraper, exact source provenance, and explicit stale/advisory
  state. A recurring importer remains deferred.
- **Official-results extension — tester/statistician:** required local coverage
  beside every score and rejected a numeric delta when task population or
  attempt policy differs. Proposed one optional reproduction cell instead of
  multiplying official submission costs across every matrix cell.
- **Official-results extension — material disagreement:** SWE-bench maintains an
  active Verified leaderboard while OpenAI now rejects it for frontier model
  measurement. The accepted plan retains it for bounded C1 historical harness
  sensitivity and excludes it from C2.
- **Cost extension — user decision:** execution is restricted to subscriptions,
  local models, and local compute. API prices are used only as a shadow
  efficiency metric; no metered API or hosted runner is authorized.
- **Final approvals — user decision:** `homelab-iac` creates and manages the
  private `agent-evals` repository; SWE-bench Verified stops after twelve C1
  tasks per harness; no initial C3 is run.

## Grill findings and accepted revisions

### Round 1 — assumption audit and pre-mortem

- A shared model name does not prove a shared request: record requested and
  observed model/reasoning identity.
- A retry is not harmless under rootless UID mapping: require fresh directories.
- Per-task network installation measures installer contention: prepare and pin
  harness artifacts before trials.
- A single overall mean hides benchmark and infrastructure differences: report
  separate paired cohorts and failure rates.
- Unlimited repeats can turn disagreement into uncontrolled spend: require
  fixed trial and cost ceilings.

### Round 2 — boundary recheck

The revised contract now survives setup failure, interruption, dataset drift,
partial pairs, secret cleanup, and quota exhaustion without manufacturing a
harness score. The final ownership and scope decisions are accepted.

### Official-results extension — two-round grill

- **Round 1, attribution audit:** a leaderboard row is a benchmark-model-harness
  system result. The revised schema keeps harness, release, attempts, date,
  verification, and missing metadata instead of grouping by display-name alone.
- **Round 1, selection audit:** selecting only top rows exaggerates quality. The
  source snapshot is labeled illustrative; a real cohort snapshot records the
  selection rule and source revision.
- **Round 2, stale-evidence pre-mortem:** upstream tables move and model aliases
  collide. Retrieval date, exact source, advisory state, and no alias inference
  prevent silent replacement.
- **Round 2, benchmark-validity recheck:** paired harness results can still
  answer sensitivity on a flawed benchmark, but cannot repair contamination or
  establish real-world frontier capability. The C2 SWE-bench gate is now
  explicit.
- **Round 2, matrix-boundary recheck:** one normalized row plus Harbor's native
  dataset/verifier boundary is sufficient for multiple benchmarks. A new plugin
  abstraction and automatic leaderboard ingestion remain unnecessary.
- **Cost boundary recheck:** actual spend and API-equivalent cost must be
  separate. Exact dated price books, complete inclusive usage, long-context
  bands, and `N/A` on missing attribution prevent false precision.

## Implementation plan

No production code or external apply occurs during `$ip`. Delivery is
leaf-first. The existing `homelab-iac` checkout is ahead, behind, and dirty;
Slice 0 must use an isolated clean worktree based on the reviewed integration
target. Never mix this work with its current Oracle, LiteLLM, fleet, or policy
changes.

### Minimum implementation surface

| Repository | Planned surface |
|---|---|
| `homelab-iac` | `github/repos/terragrunt.hcl`; existing `tests/github-hardening-contract.bats` and `tests/github-private-repos-contract.bats` |
| `agent-evals` | `pyproject.toml`, `uv.lock`, `.gitignore`, pinned CI; `features/agent-benchmark-matrix.feature`; one small `agent_evals/__main__.py` CLI; `agent_evals/prime_agent.py`; benchmark/cohort TOML; JSON price books; stdlib unit tests and fake Harbor-result fixtures |
| `homelab` | `repos.json`, proposal/index links, reviewed sanitized result summaries; remove the temporary coordination copy of the feature only after the owning copy lands |

The CLI owns only `validate`, `plan`, `run`, `resume`, and `report` commands over
Harbor. TOML uses Python `tomllib`; state and reports use JSON. Harbor remains
the execution engine. Raw jobs, credentials, sessions, downloaded harness
artifacts, and trajectories live under ignored `.local/`; Git retains only
manifests, price books, fixtures, and reviewed summaries.

### Test seams

| Seam | Catches | Misses | Cost |
|---|---|---|---|
| Existing `homelab-iac` Bats contracts plus a GitHub plan | Repository visibility/permissions, catalog drift, destructive IaC plans | GitHub provider/runtime failure until apply | Fast contract; one credentialed read-only plan |
| Python stdlib tests over fake Harbor result trees | Manifest immutability, classification, resume, pairing, price math, matrix semantics | Container, subscription, and real verifier behavior | Fast; runs on every change without credentials |
| Adapter command-capture tests | Moving installers, wrong model/reasoning, credential paths, artifact leakage, missing inclusive-usage hooks | Whether upstream binaries actually run | Fast; no provider call |
| Live C0 Harbor canary | Real Podman UID mapping, images, auth, harness install, verifier, artifact collection | Statistical harness quality | 12 subscription/local trials |
| Post-run UID-aware secret scan | Readable and mapped credential copies in raw evidence | Secrets outside the declared cohort tree | Required after every live stage |

No BDD dependency is added. Each feature scenario is bound by a named stdlib
test and must be observed RED before its minimum GREEN implementation. CI runs
no subscription model calls.

### Slice 0 — provision the private runner repository

**Owner:** `homelab-iac`. **Dependency:** clean isolated worktree and working
GitHub/OpenTofu credentials.

- **Observable result:** `ErikBPF/agent-evals` exists as a private repository
  with squash-only merge defaults, deleted merged branches, read-only Actions
  token defaults, no Action PR approval, and no auto-merge or unsupported
  private-branch protection.
- **RED:** add `agent-evals` to the expected private catalog and least-privilege
  assertions; run
  `bats tests/github-hardening-contract.bats tests/github-private-repos-contract.bats`;
  expect failure because the repository block is absent.
- **GREEN:** add one `agent-evals` block to `github/repos/terragrunt.hcl` with
  `visibility = "private"`, `protect_main = false`,
  `allow_auto_merge = false`, `default_workflow_permissions = "read"`, and
  `can_approve_pull_requests = false`. Do not change the shared module.
- **Verify:** focused Bats; then `bats tests/*.bats`, `tofu fmt -check`,
  `terragrunt hcl format --check --diff`, and repository tflint. Run a
  credentialed `terragrunt plan` in `github/repos`; accept only the three
  expected creates for repository and Actions permissions, with zero changes or
  destroys elsewhere.
- **Rollout:** apply the reviewed saved plan, then verify name, privacy, and
  Actions permissions through GitHub. If the name already exists, stop and
  import/reconcile it; never race a create.
- **Rollback:** before apply, discard the isolated change. After apply, leave a
  failed initialization private and empty; do not delete it. The module's
  `prevent_destroy`/archive boundary remains intact.

### Slice 1 — initialize, register, and transfer the contract

**Owners:** `agent-evals`, then `homelab`. **Dependency:** Slice 0.

- **Observable result:** a clean clone has deterministic credential-free CI;
  `repos.json` names `agent-evals`; the owning repository contains the feature
  contract and `homelab` links to it.
- **RED:** in the new repo, add a contract test asserting the feature, ignored
  `.local/`, and credential-free CI command; expect missing files. In `homelab`,
  add a contract assertion for the manifest entry and owning feature URL; expect
  the current local coordination path.
- **GREEN:** land the minimum file surface above, pin Actions by commit, run only
  `uv run python -m unittest discover -s tests -v`, add `agent-evals` to
  `repos.json`, and update proposal links. Remove the coordination feature only
  after the owner copy is reachable.
- **Verify:** new-repo unit tests and `uv lock --check`; `homelab` `bash
  tests/contracts.sh` and `just docs-check`.
- **Rollout/rollback:** push the owner repo before its consumer link. Revert the
  `homelab` manifest/link if the owner branch is unavailable; keep the private
  repository.

### Slice 2 — immutable cohort and expandable benchmark registry

**Scenarios:** `Record an immutable cohort before execution`; `Add another
benchmark without changing completed evidence`. **Owner:** `agent-evals`.

- **Observable result:** `validate` resolves benchmark/cohort TOML into a
  canonical JSON manifest with exact task/artifact/price-book digests; changing
  fixed identity creates a new cohort ID and cannot mutate completed evidence.
- **RED:** `test_manifest_is_immutable` and
  `test_new_benchmark_creates_distinct_cohort` fail because the CLI/schema do
  not exist.
- **GREEN:** implement the smallest TOML-to-canonical-JSON validator and digest
  function in `agent_evals/__main__.py`; seed only Terminal-Bench 2 and
  SWE-bench Verified registry rows plus Luna/xhigh C0/C1/C2 manifests.
- **Verify:** focused tests, full unit suite, and a credential-free `plan` whose
  counts are C0 `12`, C1 primary `48`/ceiling `144`, and C2 `178`.
- **Rollback:** delete only an unstarted manifest. Once trials exist, supersede
  with a new cohort; never edit the old identity.

### Slice 3 — pinned harness artifacts and secure adapters

**Scenario:** `Keep credentials outside benchmark evidence`. **Owner:**
`agent-evals`. **Dependency:** Slice 2.

- **Observable result:** preparation resolves exact Codex and Prime Agent
  versions/artifacts before trials; each adapter invokes Luna/xhigh from a
  local pinned artifact; credentials are ephemeral mounts outside `/logs` and
  `.local/jobs` contains no copied token.
- **RED:** port the prototype command-capture test and add failures for a moving
  `beta` installer, per-task network install, token-valued environment/argv,
  config under `/logs`, unpinned artifact, or missing delegated-usage capture.
- **GREEN:** retain Harbor's built-in Codex integration behind an exact CLI
  lock; implement only the Prime Agent custom adapter. Resolve Prime Agent's
  official versioned release tarball during preparation, record its SHA-256,
  mount it read-only, disable update checks, and install from that local artifact
  inside the task. Use the observed safe config root `/tmp/prime-agent-config`.
- **Verify:** adapter tests; inspect generated Harbor argv/mount JSON; run the
  token-pattern scan against synthetic readable and UID-mapped fixtures.
- **Rollout/rollback:** publish no artifact. A bad lock is replaced only by a
  new cohort; the prior cache/digest remains available for resume.

### Slice 4 — validity gate and failure taxonomy

**Scenarios:** `Require infrastructure-valid canaries before a pilot`;
`Separate infrastructure validity from harness capability`. **Owner:**
`agent-evals`. **Dependency:** Slice 3.

- **Observable result:** fake and live Harbor results distinguish setup,
  environment, credential, verifier, harness, timeout, and capability outcomes;
  unresolved infrastructure faults block the next stage.
- **RED:** table-driven tests feed one fixture per feature example and initially
  misclassify or accept them.
- **GREEN:** add one classifier and stage-gate path; infrastructure-invalid
  cells never become reward `0` and receive a fresh linked trial ID after repair.
- **Verify:** focused fixture tests, full suite, and credential-free dry-run.
- **Rollback:** retain raw diagnostics, disable the cohort, and fix the
  classifier through a new RED fixture before any rerun.

### Slice 5 — resumable local scheduler and ceilings

**Scenarios:** `Resume without rewriting completed evidence`; `Stop at an
approved ceiling`; `Require explicit approval before the full matrix`; `Reject
execution outside the accepted cohort`.
**Owner:** `agent-evals`. **Dependency:** Slice 4.

- **Observable result:** `run` schedules only planned missing cells; `resume`
  preserves completed bytes, creates fresh directories for invalid cells, stops
  at trial ceilings, and rejects metered API or hosted providers.
- **RED:** tests interrupt a fake cohort, hash completed files, attempt a
  same-directory retry, exceed each stage ceiling, request C2 without operator
  confirmation, and request SWE C2, C3, API, or hosted execution.
- **GREEN:** persist one append-only JSON state file and derive the next Harbor
  command from it. No queue service, database, or automatic retry subsystem.
- **Verify:** focused scheduler tests plus full suite; compare completed hashes
  before/after resume.
- **Rollback:** stop launching new processes; state remains resumable. Never
  delete a UID-mapped job tree directly.

### Slice 6 — shadow API pricing

**Scenarios:** `Estimate API-equivalent cost without incurring API spend`;
`Apply the price band for a long-context request`; `Refuse an unsupported
shadow price`. **Owner:** `agent-evals`. **Dependency:** Slice 2.

- **Observable result:** the accepted fixture produces `$0.033`, long-context
  requests use their price band, actual incremental spend stays `$0.00`, and
  incomplete/local-unpriced usage returns `N/A` with a reason.
- **RED:** bind the three exact feature examples and observe missing estimator
  failures.
- **GREEN:** add one pure decimal calculation using disjoint usage categories
  and the immutable JSON price book; reject floats, aliases, and partial child
  attribution.
- **Verify:** focused pricing tests, boundary values at 272000/272001 input
  tokens, full suite.
- **Rollback:** reports retain the old price-book digest; corrected rates create
  a new report revision without rewriting raw usage.

### Slice 7 — paired benchmark aggregation

**Scenarios:** `Compare only complete task pairs`; `Keep benchmark reports
distinct`. **Owner:** `agent-evals`. **Dependencies:** Slices 4-6.

- **Observable result:** `report` emits benchmark-native pass/reward,
  wins/ties/losses, invalid/missing cells, latency, usage, actual spend, and
  shadow cost; incomplete pairs stay excluded and visible.
- **RED:** fixtures include complete, missing, digest-mismatched, invalid, zero,
  and zero-solve pairs and initially produce no valid report.
- **GREEN:** aggregate directly from immutable result JSON; emit one JSON and
  Markdown report per benchmark. No cross-benchmark mean.
- **Verify:** focused golden-data assertions plus full suite; regenerate twice
  and require byte-identical output.
- **Rollback:** remove only the derived report and regenerate from raw evidence.

### Slice 8 — official context and quality advisories

**Scenarios:** `Preserve an official result as a system result`; `Retain a
benchmark quality advisory`. **Owner:** `agent-evals`. **Dependency:** Slice 2.

- **Observable result:** a manually reviewed dated source snapshot preserves
  benchmark/model/harness identity, missing fields, verification, and advisory;
  it cannot become a model-only claim.
- **RED:** fixtures omit a harness, source date, or active advisory and are
  rejected; a complete row initially lacks a loader.
- **GREEN:** validate checked-in JSON snapshots only. Do not add a scraper or
  network call.
- **Verify:** focused tests and source-selection review against the recorded
  official URL/revision.
- **Rollback:** remove an invalid contextual row; local benchmark evidence is
  unaffected.

### Slice 9 — official-versus-ours matrix

**Scenarios:** `Separate official context from a local paired result`; `Render
the benchmark model harness matrix`; `Calculate a direct official delta only
for compatible cohorts`. **Owner:** `agent-evals`. **Dependencies:** Slices 7-8.

- **Observable result:** the final table shows benchmark, model, harness,
  official score, our score, coverage, delta, and comparison class; incompatible
  or partial populations produce `Delta = N/A` with a reason.
- **RED:** comparison fixtures attempt model aliasing, mixed harness identity,
  partial/full ranking, and cross-benchmark pooling.
- **GREEN:** join only exact identities and compute delta only after every
  compatibility field matches.
- **Verify:** focused matrix tests, full suite, and reviewed Markdown snapshot.
- **Rollback:** regenerate from preserved local/official inputs; never edit a
  source row to force comparability.

### Slice 10 — live staged execution and evidence handoff

**Owner:** `agent-evals`, then `homelab`. **Dependencies:** Slices 0-9 green.

- **C0 rollout:** start at concurrency `1`; run the fixed 12 trials. Increase to
  `2` only in a new calibration cohort after zero unresolved infrastructure and
  subscription-throttle errors. Do not return directly to `4`.
- **C0 gate:** all adapters/environments/verifiers valid, resume proven, secret
  scan clean, requested and observed Luna/xhigh recorded.
- **C1 rollout:** run 48 primary trials—twelve Terminal-Bench and twelve
  SWE-bench tasks per harness—with a hard 144-trial ceiling for symmetric
  repeats. Stop cleanly on subscription quota exhaustion.
- **C1 gate:** complete pairs, distinct benchmark reports, inclusive usage
  coverage, and decision-useful harness signal. SWE-bench ends here.
- **C2 rollout:** run 178 Terminal-Bench primary trials only, after explicit
  operator confirmation of the C1 report and clean local capacity check.
- **Verification:** rerun deterministic tests before each stage; after each
  stage run UID-aware secret scan, manifest/result digest verification, exact
  cell-count check, and report regeneration.
- **Handoff:** commit only reviewed manifests, aggregate tables, failure summary,
  and recommendation to `agent-evals`; update `homelab` proposal/index with a
  link and status. Raw `.local/` evidence stays local.
- **Rollback:** stop the local process/service, preserve immutable state, and
  resume only missing or explicitly invalid cells. No C3 or public submission.

### Scenario-to-slice map

| Feature scenario | Slice |
|---|---:|
| Record an immutable cohort before execution | 2 |
| Require infrastructure-valid canaries before a pilot | 4 |
| Compare only complete task pairs | 7 |
| Separate infrastructure validity from harness capability | 4 |
| Resume without rewriting completed evidence | 5 |
| Keep credentials outside benchmark evidence | 3 |
| Stop at an approved ceiling | 5 |
| Estimate API-equivalent cost without incurring API spend | 6 |
| Apply the price band for a long-context request | 6 |
| Refuse an unsupported shadow price | 6 |
| Keep benchmark reports distinct | 7 |
| Preserve an official result as a system result | 8 |
| Separate official context from a local paired result | 9 |
| Render the benchmark model harness matrix | 9 |
| Calculate a direct official delta only for compatible cohorts | 9 |
| Add another benchmark without changing completed evidence | 2 |
| Retain a benchmark quality advisory | 8 |
| Require explicit approval before the full matrix | 5 |
| Reject execution outside the accepted cohort | 5 |

### `/ip` two-round grill and CodeHero gates

- **Round 1 — Anti-Consensus:** reusing `homelab`, a harness flake, or Servarr
  would save repository creation but violate the accepted neutral ownership.
  The plan keeps the new repository intentionally small: one CLI module, one
  custom adapter, Harbor-native datasets/verifiers, no service or scraper.
- **Round 1 — easy-agreement check:** copying the working prototype would also
  copy a moving beta installer and the currently RED timeout test. It is used
  only to seed tests; GREEN code starts from pinned artifacts and a calibrated
  serial canary.
- **Round 2 — pre-mortem:** an IaC apply could touch unrelated GitHub state, an
  empty repository could be exposed, a retry could reuse a UID-mapped tree, or
  delegated usage could be underpriced. Exact-plan review, private defaults,
  fresh trial IDs, and `N/A` pricing close those failures.
- **Security:** private repo; read-only Actions; no benchmark credentials in CI;
  ephemeral runtime mounts; pinned/digested upstream artifacts; post-run scan.
- **Reliability/operations:** append-only state, fresh retry directories,
  serial-first C0, bounded concurrency, resumable quota stops, retained raw
  diagnostics, no always-on service.
- **Performance:** prefetch artifacts once; never parallelize cold moving
  installs; calibrate `1 -> 2` before raising concurrency.
- **Architecture/compatibility:** leaf-first ownership, schema/cohort versions,
  exact Harbor/harness locks, no duplicate execution engine.
- **Tests:** Bats for IaC, stdlib fixture tests for behavior, live C0 for real
  integration. Accessibility is not applicable because no UI is introduced.

## Risks and review gates

| Risk | Gate |
|---|---|
| Infrastructure failures masquerade as capability failures | C0 must show zero unresolved infrastructure errors; taxonomy tested |
| Dataset or harness drift invalidates pairing | Immutable manifest and digest equality |
| Subscription token reaches logs/artifacts | Ephemeral mount, non-artifact config path, post-run UID-aware scan |
| Parallel branches trigger provider limits | C0 concurrency calibration and shared rate policy |
| Full matrix consumes unbounded quota or time | Fixed C0/C1/C2 trial ceilings, local capacity gate, resumable quota stop |
| Resume duplicates or overwrites evidence | Immutable completed cells; fresh IDs for missing/invalid cells |
| Runner repository becomes a second Harbor | Reuse Harbor interfaces; own only manifests, adapters, orchestration, and aggregation |
| Cross-benchmark score is misleading | No pooled reward; benchmark-specific reports |
| Official system scores are mislabeled as model scores | Preserve harness and comparison class on every row |
| External source changes after review | Dated source snapshot and revision; stale state is visible |
| Flawed or contaminated tasks create false capability claims | Source advisory plus bounded sensitivity use; no frontier claim |
| Partial local score is compared with a full official score | Always show coverage; numeric delta requires identical task population |
| Official attempt policy multiplies trials | C3 is excluded from the accepted program |
| Shadow price is mistaken for money spent | Separate actual and shadow fields; actual incremental spend remains zero |
| Delegated usage is omitted | Require inclusive root-plus-child usage coverage before pricing Prime Agent |
| A current rate rewrites old evidence | Store immutable dated price-book digest per cohort |

Applicable specialist gates: security, reliability, performance, architecture,
test quality, compatibility, and operations. Accessibility is not applicable
because no user interface is proposed.

## Non-goals

- ranking unrelated models or providers in the first cohort;
- mirroring every public leaderboard or keeping an always-current scraper;
- claiming an official system result was caused by its model alone;
- tuning prompts, reasoning, timeouts, or tools per harness to maximize score;
- replacing Harbor, benchmark verifiers, or registered datasets;
- changing Codex, OpenCode, or production agent defaults;
- storing credentials, raw trajectories, or repository payloads in Git;
- allocating subscription fees, electricity, or hardware depreciation to a
  trial;
- guessing an API price for a local model without an exact published rate;
- uploading results or submitting a public leaderboard entry;
- creating an always-on benchmark service;
- implementing runner code during `$pl` or `$ip`.

## References

- [Harbor core concepts](https://www.harborframework.com/docs/core-concepts)
- [Harbor agent integrations and custom agents](https://www.harborframework.com/docs/agents)
- [Harbor datasets and composite datasets](https://www.harborframework.com/docs/datasets)
- [Harbor evaluation examples for Terminal-Bench and SWE-bench](https://www.harborframework.com/docs/run-jobs/run-evals)
- [Harbor registry dataset inventory](https://hub.harborframework.com/datasets)
- [Terminal-Bench registry record](https://hub.harborframework.com/datasets/terminal-bench/terminal-bench/latest)
- [Terminal-Bench 2.0 official leaderboard](https://www.tbench.ai/leaderboard/terminal-bench/2.0)
- [Terminal-Bench 2.0 submission and validation rules](https://huggingface.co/datasets/harborframework/terminal-bench-2-leaderboard)
- [SWE-bench Verified](https://www.swebench.com/verified.html)
- [SWE-bench official leaderboards](https://www.swebench.com/)
- [SWE-bench official result records](https://github.com/swe-bench/experiments)
- [SWE-bench harness and resource requirements](https://www.swebench.com/SWE-bench/reference/harness/)
- [OpenAI: SWE-bench Verified no longer measures frontier coding capabilities](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/)
- [OpenAI: Separating signal from noise in coding evaluations](https://openai.com/index/separating-signal-from-noise-coding-evaluations/)
- [OpenAI API: GPT-5.6 Luna model and pricing](https://developers.openai.com/api/docs/models/gpt-5.6-luna)
- [Prime Agent quickstart and versioned release artifacts](https://github.com/PrimeIntellect-ai/prime-agent/blob/main/packages/coding-agent/docs/quickstart.md)
- [Prime Agent release-manifest and offline settings](https://github.com/PrimeIntellect-ai/prime-agent/blob/main/packages/coding-agent/docs/settings.md)
- [`repos.json`](../../repos.json)
- [Repository SSOT/SRP decision](../decisions/2026-06-29-repo-ssot-srp.md)
- [Orion Qwen3.8 coding benchmark](https://github.com/ErikBPF/servarr/blob/main/machines/orion/QWEN38-CODING-BENCHMARK.md)
