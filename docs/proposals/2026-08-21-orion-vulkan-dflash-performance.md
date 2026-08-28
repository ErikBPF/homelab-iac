# Orion Vulkan DFlash performance

**Status:** Shared verdict runner and D1.3 attribution implemented; source audit
closed D1 because the measured output projection is required by the DFlash2
selector. D2 now has one semantics-preserving, same-image Vulkan integer-dot
route probe implemented and rejected by live A/B; no optimizer, production, or
host-driver change is authorized — 2026-08-21.

## Goal

Improve text-only, single-request Qwen3.8 coding throughput with DFlash2 on
Orion's RX 9070 XT under Linux/RADV Vulkan. Preserve correct responses,
reproducible evidence, and automatic restoration of the production server.

This record coordinates ownership. `servarr` owns benchmark recipes, image pins,
raw evidence, and workload rollout. llama.cpp or a traceable patch artifact owns
engine changes. `desktop-nixos` owns Mesa, kernel, and Orion host activation.
Runtime secrets remain in Vault; this proposal needs none.

The detailed baseline is the Servarr
[Qwen3.8 coding benchmark](https://github.com/ErikBPF/servarr/blob/main/machines/orion/QWEN38-CODING-BENCHMARK.md).
Observable behavior is fixed by its unautomated
[Vulkan DFlash feature contract](https://github.com/ErikBPF/servarr/blob/main/machines/orion/features/vulkan-dflash-performance.feature).
Bind that contract through the existing `spec-matrix.sh` and
`test_benchmark_runners.py`; do not add a Gherkin dependency.

## Grounded evidence

- Vulkan remains Orion's fastest measured backend. Official ROCm b10524 with
  DFlash2 n=3 reached 44.73 generation tok/s; the prior Vulkan DFlash n=2 lane
  reached 53.14 tok/s.
- DFlash2 PR 27342 is open at commit
  `5ecbe1ac17ec0484c5b44af0bd580cdc9c428ed4`. DFlash2 adds grouped dynamic
  depthwise convolution and a candidate selector to the DFlash path.
- The latest official Vulkan image checked for this work is b10524, commit
  `9ee9fc04c136ef2ae729bfc60d18961b23c13ddf`, amd64 digest
  `sha256:1ab197e502f9812cac56478a22f22bd5c656cea217ba51e2b3ca73c88e2875ae`.
  Upstream tags have reached b10539, but no matching Vulkan image tag is
  published and the moving `server-vulkan` manifest still identifies b10524.
- Orion's current production runtime sees RADV GFX1201 from Mesa 26.2.0 on
  kernel 7.1.8. Driver A/B evidence must record both versions.
- `MrLordCat/llama.cpp-rdna-lab` contains relevant RDNA4 work but reports Windows,
  dual-RX-9070-XT, proprietary-driver results. It is a patch source, not a Linux
  deployment candidate.
- The fork's smallest CUDA-parity patch changed Vulkan q8_1 scaling and rounding.
  Seeded Linux A/B was neutral at n=2 and regressed n=3 generation throughput
  2.30%, so that isolated patch is rejected.
- CUDA quantizes q8_1 with `127/amax` and `roundf`. Current Vulkan still uses
  `1/(amax/127)` and GLSL `round()`. Both backends use packed int32 dot
  accumulation for the relevant Q8_0 x Q8_1 route, but the final scale
  multiplication order and pre-quantized route behavior differ. The complete
  parity unit remains open.
- Current upstream already selects large cooperative matmul for AMD devices on
  non-proprietary drivers. The fork's proprietary-driver auto-default does not
  solve an Orion/RADV gap.
- The initial instrumentation-only 5ec image
  `localhost/llama-server-vulkan:dflash2-profile-5ecbe1ac` has image ID
  `e3a73cd46ead8200277816290a91d18c50394637b73ee27bebbb68aa05654541`
  and patch identity `dflash-profile-v1`. Across repeated request samples,
  draft decode consumed 84.3–88.6% of measured DFlash CPU-phase wall time at
  n=2 and 84.4–86.9% at n=3. It dominated every sample; selector and
  target-copy time were each below 0.5% cumulatively.
- Exact 5ec already supports `GGML_VK_DISABLE_INTEGER_DOT_PRODUCT`; setting it
  selects the existing non-integer-dot Vulkan matmul route without changing the
  image, model, graph, or DFlash selector. Upstream AMD evidence is mixed: it
  repaired a severe Q4_K decode regression on Radeon 8060S, while an RDNA4/RADV
  sweep measured it as neutral. Orion therefore needs a same-image A/B rather
  than a new kernel or an assumed win.
- The planned D2 numeric RED cannot use upstream `test-backend-ops` as written.
  Explicit Q8_0 x Q8_1 cases at K=10240 and n=1/n=2/n=32 were all reported
  `not supported [CPU]`, so the command executed 0/0 tests. Per D2.1's stop
  gate, no shader or route patch was created from that unobserved premise.
- The initial D1 timer wrapped `llama_decode(ctx_dft)` plus an explicit profile
  synchronization. The public `llama_get_embeddings_nextn()` call that follows
  already synchronizes the context, so the explicit call changes attribution,
  not required behavior. Separately, `GGML_VK_PERF_LOGGER` fences every profiled
  graph before returning. The retained 84–89% share therefore identifies draft
  graph completion, but cannot distinguish CPU submission from GPU wait or be
  used as a production-overlap measurement.
- The revised exact-5ec profile image has ID
  `8e207d8215521a5038d8ad3ae3d1b94369f325a62de6f32d8da007911b8b77e6`
  and patch identity `dflash-profile-v2`. Unfenced n=2/n=3 lifecycle runs put
  the existing output-read wait at 51.72%/51.56% of measured DFlash phase time
  and draft submission at 34.64%/33.29%. Every request reported zero draft
  graph reuse.
- The separate marker-bounded dispatch probe retained balanced begin/end
  markers and identified `result_output`, the q4_K full-vocabulary projection,
  at both widths. Individual bounded calls took about 1.14–2.68 ms. Generic
  `node_*` spikes were not stable across widths. The Vulkan logger fences every
  graph, so its throughput and submit/wait split remain non-verdict evidence.

## Party ledger

- Product/domain: optimize end-to-end coding generation throughput, not an
  isolated kernel score or acceptance percentage.
- Developer/architecture: separate DFlash graph work, reusable llama.cpp Vulkan
  work, and RADV compiler work so each is measurable and revertible.
- Tester/operator: pin model, commit, digest, driver fingerprint, flags, prompts,
  and seed; compare adjacent order-swapped runs; keep losing reports.
- CodeHero risk review: external commits and images stay pinned and audited;
  driver tests are reversible runtime/image overrides before any host activation;
  failed runs must restore the pinned healthy server.
- Resolved disagreement: CUDA is a semantic and algorithmic reference, not a
  source of RDNA4 launch constants. Geometry is measured on Orion.

## Decision map

### Destination, actors, and outcomes

- Coding-agent caller: lower generation latency on the existing text workload.
- Orion operator: one-command, hostname-only A/B runs with raw reports and safe
  production recovery.
- Upstream maintainer: small attributable patches with CUDA or driver evidence,
  not a wholesale fork import.
- Observable end state: one pinned Vulkan+DFlash image that beats its adjacent
  production control under the shared contract, or a retained negative result
  that closes the tested route.

### D1 — DFlash2 improvements

Owner: DFlash speculative runtime and Qwen graph code in llama.cpp; Servarr owns
the Orion evaluation.

Determine whether grouped dynamic depthwise convolution, candidate selection,
hidden-state handoff, or verifier lifecycle dominates Vulkan-only cost. Use the
same DFlash2 commit on local Vulkan and ROCm/HIP, with CUDA source behavior as
the semantic reference. Retain only changes attributable to these DFlash
operators or their draft/verify lifecycle.

Draft-width tuning is configuration, not an engine patch. n=2 and n=3 are the
only widths in this effort.

### D2 — llama.cpp Vulkan improvements

Owner: generic `ggml-vulkan` kernels, dispatch, and scheduler code; Servarr owns
the patched image and pin.

Use CUDA implementations as exact semantic references. The first unresolved
candidate is the complete q8_1 and Q8_0 x Q8_1 parity unit: quantization,
pre-quantized input routing, packed-dot block accumulation, and matching final
scale multiplication order. The rounding-only subset is closed.

Profile route and dispatch overhead before considering graph reuse or warm
verifier topology. A change that also affects MTP or non-DFlash Vulkan belongs
here. Do not port the proprietary-driver large-matmul default. Do not port
dual-GPU scheduler-copy changes without measured single-GPU copy overhead.

### D3 — AMD Linux driver improvements

Owner: `desktop-nixos` for reversible Mesa/RADV or kernel activation; Mesa RADV
and ACO upstream own accepted driver code.

Run a binary-identical A/B: unchanged llama.cpp code, model, and flags, with only
the Mesa/RADV runtime changed. Capture pipeline statistics and the exact SPIR-V
or dispatch trace. During discovery, use a reversible runtime or image override;
do not replace Orion's host driver.

Escalate to Mesa only when identical SPIR-V or a minimal compute reproducer
demonstrates a compiler/driver limit. Escalate from Mesa to kernel `amdgpu` only
when evidence crosses the userspace boundary. Without a reproducer, ownership
returns to the llama.cpp lane.

## Dependencies and review gates

1. Every comparison records target/draft artifacts, llama.cpp commit, image
   digest, Mesa/kernel fingerprint, flags, prompts, seed, and run order.
2. DFlash attribution requires per-operator or per-dispatch timing. Aggregate TG
   cannot assign ownership.
3. Driver attribution requires an unchanged application binary and minimal
   SPIR-V reproducer.
4. A candidate is promotable only when its paired per-request TG improvement has
   a positive 95% confidence interval, response checks pass, and production is
   healthy after the run.
5. Profiling instrumentation is disabled for the final A/B. Performance,
   correctness, patch provenance/licensing, rollback, and host compatibility are
   reviewed before production pinning or upstream submission.

## Open questions

- Can the DFlash full-vocabulary `result_output` projection and following top-k
  selector avoid materialized logits or otherwise reuse the CUDA-reference
  selection path without changing accepted candidates?
- Which runnable CUDA-reference seam can validate direct pre-quantized Q8_1
  routing and multiplication order before D2 is reopened?
- Does the newest Mesa/RADV runtime move the pinned workload outside the
  control-run confidence interval?
- If a shader remains slow, does identical SPIR-V reproduce the gap outside
  llama.cpp?

## Risks

| Risk | Gate |
|---|---|
| Open DFlash2 code changes or breaks model behavior | Pin commit; response checks; no automatic upstream refresh |
| Fork patch mixes unrelated Windows/dual-GPU work | Port one attributable unit; audit provenance and diff |
| Benchmark noise promotes a false gain | Seeded paired requests, reversed order, positive 95% confidence interval |
| Profiling overhead becomes the claimed gain | Disable instrumentation in final A/B |
| Mesa test destabilizes Orion | Runtime/image override first; `desktop-nixos` review before activation |
| Failed experiment leaves production down | Trap cleanup and explicit health gate |

Security applies to external source/image provenance and remote execution. No
secret is required, builds stay pinned, and benchmark output must not include
environment secrets. Accessibility is not applicable: no user interface changes.

## D1 and D2 implementation plan

### Fixed point, ownership, and order

Both plans target DFlash2 commit
`5ecbe1ac17ec0484c5b44af0bd580cdc9c428ed4`, the revision used by all Orion
evidence. PR 27342 has since moved to
`1deefcca395743049c3820ab8f9b15043f3e9446`; rebasing is a separate
compatibility gate after these slices, never an implicit build input.

`servarr` owns the runner, reports, patch artifacts, image publication, digest
pin, workload rollout, and rollback. The patch artifact is the leaf for local
delivery; a corresponding llama.cpp commit or pull request remains the preferred
long-term engine owner. `homelab` owns this plan and final decision record.
`desktop-nixos` is not touched by D1 or D2.

Execution order is shared benchmark contract, D1 attribution, then D2 numeric
parity and uninstrumented A/B. D1 may select a later DFlash optimization plan;
it does not block testing the already-settled D2 parity unit. Candidate
publication remains last. Production rollout is not in these plans because the
incumbent b10398/MTP workload and the 5ec/DFlash experiment differ in more than
one lane.

### Public test seams

| Seam | Catches | Misses | Cost | Decision |
|---|---|---|---:|---|
| `machines/orion/tests/test_benchmark_runners.py` plus JSON fixtures | Width/order restrictions, actual-container fingerprinting, response checks, pairing, confidence verdict, cleanup contract | GPU behavior | Low | Select |
| Existing `GGML_VK_PERF_LOGGER`, with an instrumentation-only node-name prefix | Per-dispatch Vulkan time for DFlash graph regions | CPU copies and server lifecycle | Medium | Select for D1 only |
| Existing speculative statistics plus narrow DFlash phase counters | Target-feature copy, encoder, injection/decode/sync, draft decode, CPU selector | Shader ownership inside a graph | Medium | Select for D1 only |
| Existing llama.cpp `test-backend-ops` with explicit Q8_0 x Q8_1 shapes | Backend numeric divergence on MMVQ and MMQ shapes | End-to-end acceptance and throughput | Medium | Select for D2 |
| Seeded Orion server A/B through `spec-matrix.sh` | Real response, acceptance, TG, recovery, driver/model compatibility | Fine-grained ownership without profiling | High | Select as final acceptance |
| Fork `dump_nextn` example or a new Gherkin runtime | Intermediate dumps or executable feature syntax | Adds duplicate harness and maintenance surface | High | Reject; add only if selected seams disagree |

No new statistics, Gherkin, benchmark, or profiling dependency is allowed.
Python standard library code is sufficient for the paired verdict.

### S0 — bind the shared experiment verdict

**Scenarios and observable.** Bind “Compare one isolated candidate,” “Retain a
measurable candidate,” and “Recover production after a failed experiment.” One
hostname-only command runs candidate/control at n=2 and n=3 in both orders,
retains every raw result, exits non-zero for an invalid or losing candidate,
and ends with the pinned production server healthy.

**RED.** Add contract cases first, then run:

```sh
cd /home/erik/Documents/erik/servarr
python3 -m unittest machines/orion/tests/test_benchmark_runners.py
```

Expected failures: the runner still permits wider DFlash filters, fingerprints
`llama-chat` instead of `qwen38-spec-bench`, emits no candidate/control/lane/order
identity, does not validate response content, and has no paired 95% confidence
verdict.

**Minimum GREEN surface.** Modify only `spec-matrix.sh`, `benchmark.sh`, the
existing unittest, and one small standard-library comparison CLI under
`machines/orion/scripts/`.

- Add a comparison mode that accepts explicit control image, candidate image,
  and lane; internally run exactly n=2 and n=3 in control-candidate and
  candidate-control order. Keep `--list` behavior unchanged.
- Validate image references against a conservative OCI-reference syntax before
  interpolation into a remote command; candidate input never becomes arbitrary
  shell or container arguments.
- Pass the benchmark container name explicitly. Fingerprint that container's
  configured image, immutable local image ID or registry digest, revision label,
  arguments, RADV environment, Mesa, and kernel. Never dump the full environment.
- Record lane, variant, order, width, run, prompt, seed, HTTP success, non-empty
  response content, timing fields, and artifact identities in each report.
- Pair rows by width, order, run, and prompt. Reject missing or duplicate pairs,
  mismatched fixed inputs, failed responses, or any n=4+ row. Use a deterministic
  fixed-seed paired bootstrap over TG deltas and require each width's 95% lower
  bound to exceed zero. Report PP and acceptance but do not promote on them.
- Preserve the current trap, additionally poll production `/health` after
  restoration, and fail cleanup if `qwen38-spec-bench` remains or production
  does not become healthy.

**Verification.** Focused: the unittest covers a winning fixture, zero-crossing
CI, reversed order, failed response, metadata mismatch, duplicate/missing pair,
n=4 rejection, and cleanup command. Broader:

```sh
bash -n machines/orion/scripts/spec-matrix.sh
bash -n machines/orion/scripts/benchmark.sh
python3 -m unittest discover -s machines/orion/tests -p 'test_*.py'
```

Live smoke uses `REMOTE_HOST=orion`; no address or deeper Tailscale target is
accepted. It runs one deliberately invalid image and proves automatic recovery
before any performance matrix.

**Dependencies, owner, rollout, rollback.** Owner: Servarr. Depends only on the
accepted feature contract. Runner changes deploy nowhere and do not edit the
production compose file. Rollback is reverting these runner files; raw negative
and failure reports remain retained.

### D1 — attribute DFlash cost before choosing an optimizer

#### D1.1 — profiling-only DFlash image and attributed report

**Scenario and observable.** Bind “Attribute a DFlash-specific improvement” up
to its ownership decision. For n=2 and n=3, produce one JSON attribution report
whose categories cover DFlash local convolution graph work, selector graph and
CPU selection, target-feature handoff/injection, draft decode, and target
verification. The report records profiled wall time and dispatch time separately;
overlap means the categories are not summed as if they were mutually exclusive.

**RED.** With the unmodified pinned source, run a single seeded profiled request
through the S0 runner and then the attribution parser. Expected failure: Vulkan
timings omit graph node names, `common_speculative_process()` is untimed, and the
DFlash implementation exposes only aggregate draft duration.

**Minimum GREEN surface.** Create one traceable, instrumentation-only llama.cpp
patch and a matching ephemeral Servarr build recipe.

- Reuse `GGML_VK_PERF_LOGGER`; only prefix its existing records with the ggml
  tensor/node name when a profiling environment flag is present. Do not create a
  second Vulkan timing system.
- Add microsecond counters around DFlash target-feature extraction/copy,
  `llama_encode`, injection copy plus `llama_decode`/synchronize, draft
  `llama_decode`, and CPU lattice selection. Add process duration to the existing
  speculative statistics. Emit fixed keys only when profiling is enabled.
- Use existing server decode timers for target verification. The Servarr parser
  joins these counters with named Vulkan records such as `attn_conv_in`,
  `attn_conv_out`, `ffn_conv_in`, `ffn_conv_out`, and `dflash2_lattice`.
- Keep profiling disabled by default. Never use this image for a throughput
  verdict or production pin.

**Verification.** Focused source checks compile the profiling patch against the
exact pinned commit. A one-request n=2 smoke must contain every fixed timing key,
finite non-negative durations, node-labelled Vulkan records, the source commit,
and driver fingerprint. Broader live verification repeats three requests at n=2
and n=3 and retains raw container logs plus parsed JSON. ROCm/HIP on the same
commit is a semantic/cost reference only, not a promotion candidate.

**Dependencies, owner, rollout, rollback.** Owner: llama.cpp patch artifact;
Servarr owns build and evidence. Depends on S0. Rollout is an isolated
`qwen38-spec-bench` container on port 8081. Rollback removes that container and
restores the pinned production server; the profiling image is never published
as a consumer artifact.

#### D1.2 — decision gate

The attribution report must name one dominant category at both widths and show
that the measurement is stable across repeated requests before an engine change
is selected. If it does, update this proposal and rerun `$ip` for exactly that
owner: DFlash graph, CPU selector, handoff/injection, or verifier lifecycle. If
it does not, retain the result and close D1 without an optimization patch.

This gate deliberately excludes conditional production code. In particular, do
not pre-port MTP device handoff, invent a fused depthwise operator, or move the
selector to the GPU before the report identifies that cost. Draft-width tuning
also remains configuration, not a D1 patch.

**Execution result — 2026-08-21.** Gate passed for ownership only. The retained
n=2/n=3 raw logs and parsed JSON show draft decode as the dominant category in
every repeated sample, with 84.3–88.6% share at n=2 and 84.4–86.9% at n=3.
The next action is a new `$ip` scoped to the DFlash draft-decode/verifier
lifecycle. This result does not authorize an optimizer, fused operator, or
production patch.

#### D1.3 — split submit, wait, and draft dispatch before choosing an optimizer

**Scenario and observable.** Continue “Attribute a DFlash-specific improvement”
without changing production behavior. At n=2 and n=3, an unfenced lifecycle
report separates CPU submission of `llama_decode(ctx_dft)` from the wait already
performed by `llama_get_embeddings_nextn()`, and records the draft context graph
reuse delta. A separate short, fenced probe reports only Vulkan records emitted
between draft begin/end markers. Neither report is a throughput verdict.

**Candidate test seams.** Reuse the existing Servarr unittest, profile parser,
opt-in llama.cpp patch, exact-commit build recipe, and hostname-only live runner.
Do not add a profiler, statistics package, Gherkin runtime, or new backend API.
The lifecycle mode must omit all `GGML_VK_PERF_LOGGER*` variables. The dispatch
mode may enable the existing logger at frequency 1 only for a fixed short probe.

**RED.** Extend parser fixtures first to require cumulative and per-request
`draft_submit_us`, `draft_wait_us`, and `draft_graph_reused` fields and a
marker-bounded `draft_vulkan_us` map. Extend runner source checks to prove the
lifecycle mode has no Vulkan logger and the dispatch mode is short and fenced.
Expected failures: the current patch reports one combined `draft_decode_us`,
adds a redundant explicit synchronization, and aggregates Vulkan records from
all graphs.

**Minimum GREEN surface.** Revise only the existing profile patch, parser,
runner mode, its unittest, and the existing labelled profile build recipe.

- Time `llama_decode(ctx_dft)` as submit. Remove the profile-only explicit
  synchronization; time the first `llama_get_embeddings_nextn(ctx_dft)` access
  as wait, preserving its existing automatic synchronization.
- Read `llama_perf_context(ctx_dft).n_reused` after the wait and report a delta.
  Do not add production counters or alter the public llama API.
- Emit fixed begin/end markers only while profiling. In dispatch mode, parse
  Vulkan timings only inside those markers. Use frequency 1 and a small fixed
  prediction count so logger aggregation cannot cross graph boundaries.
- Keep n=2/n=3, parallel 1, exact commit, models, prompt, seed, driver
  fingerprint, isolated port, cleanup trap, and production health gate.

**Verification and decision gate.** Focused checks apply and compile the revised
patch against exact 5ec, exercise decreasing/missing counters and malformed
markers, and run the full Orion runner unittest plus shell syntax checks. Live
verification runs three unfenced requests at each width, then one short dispatch
probe per width. If submit or graph-rebuild cost dominates, ownership moves to a
new generic llama.cpp graph/scheduler `$ip`. If wait dominates and one draft
dispatch family is stable at both widths, return through `$ip` for exactly that
DFlash graph operator. Otherwise retain the negative result and close D1. No
optimizer or candidate A/B is part of D1.3.

**Ownership, rollout, rollback.** The llama.cpp patch artifact owns
instrumentation; Servarr owns image, runner, parser, and evidence. Rollout is
only `qwen38-spec-bench` on port 8081 through hostname `orion`. Rollback removes
that container and restores/health-checks production. The profile image remains
ineligible for publication or production.

**Execution result — 2026-08-21.** D1.3 passed and selected a DFlash-local owner.
The retained unfenced lifecycle reports show wait dominating at both widths:
51.72% for n=2 and 51.56% for n=3, versus 34.64% and 33.29% for submit. Draft
graph reuse was zero in all 18 request samples, but submit did not dominate.
The short fenced reports contain balanced markers (2/2 at n=2 and 4/4 at n=3)
and consistently expose the q4_K full-vocabulary `result_output` projection;
individual calls took approximately 1.14–2.68 ms. Unstable generic `node_*`
outliers are rejected as an optimization target. The next `$ip` is therefore
limited to the DFlash output-projection/top-k selection path, grounded against
the CUDA implementation. No generic Vulkan, AMD driver, production, or
candidate A/B change is authorized by this profiling slice.

#### D1.4 — source-audit planning return

The follow-up `$ip` stopped before producing implementation slices. Exact 5ec
source shows that `result_output` is not an avoidable materialization: DFlash2
runs `ggml_top_k()` over those logits, gathers each candidate's unary logit, and
adds that score to the selector lattice. The upstream DFlash2 formula likewise
defines `unary[c]` as the draft's own score. Removing or approximating the full
projection would therefore change candidate selection, outside the accepted
behavior contract.

CUDA is not a fusion reference. Its `GGML_OP_TOP_K` consumes an already computed
F32 tensor and separately uses CUB `DeviceTopK::MaxPairs` or an argsort fallback.
A fused quantized projection/top-k operation would be a new generic ggml/backend
semantic unit, not the authorized DFlash-local patch. The existing optional
`d2t` reduced-vocabulary path is the smaller mechanism, but Orion's profiled
checkpoint uses the target's full 248,320-row output projection; changing its
candidate domain requires a compatible model artifact and a new acceptance
decision.

One `$party`/map/grill round preserved the disagreement instead of inventing a
kernel contract. Product and test ownership require unchanged candidate scores;
architecture assigns any fused operation to generic llama.cpp backends;
operations reject a new production artifact without a compatible checkpoint;
simplicity rejects speculative cross-backend code. D1 is closed. Reopen only
when either an upstream-compatible reduced-vocabulary DFlash2 checkpoint exists,
or a separate generic fused projection/top-k proposal supplies a CPU reference,
CUDA/Vulkan conformance tests, and a non-DFlash control. The existing `.feature`
contract remains unchanged because neither behavior is accepted.

### D2 — complete the reusable Vulkan Q8 parity unit

#### D2.1 — numeric RED, minimal parity patch, and candidate image

**Scenario and observable.** Bind the numeric part of “Attribute a generic
llama.cpp Vulkan improvement.” At representative n=1/n=2 vector and wider MMQ
shapes, Vulkan Q8_0 x Q8_1 output follows the CUDA semantic unit: CUDA q8_1
quantization, direct pre-quantized Q8_1 routing, one packed int32 dot sum per
32-element block, and the same final scale multiplication order.

**RED.** First add explicit Q8_0 x Q8_1 cases to the existing backend-op test,
including DFlash/MTP-like K=10240 shapes. Build tests from the exact pinned
source and run on Orion:

```sh
GGML_VK_PERF_LOGGER=1 ./build-vulkan/bin/test-backend-ops test \
  -b Vulkan0 -o MUL_MAT -p 'type_a=q8_0,type_b=q8_1'
```

Expected RED: the current `qy_needs_dequant` predicates route pre-quantized
Q8_1 through conversion instead of the Q8_1 MMVQ/MMQ pipeline, and strict
CUDA-reference boundary vectors expose the remaining scale-order divergence.
If the targeted cases neither fail nor expose that route, stop without changing
shaders and record the premise as disproved.

The already-retained end-to-end RED is the rounding-only candidate: n=3 TG
regressed 2.30%, so it cannot satisfy S0's positive-confidence verdict.

**Execution result — 2026-08-21.** The numeric seam stopped before shader work.
Three explicit Q8_0 x Q8_1 cases covering K=10240 and n=1/n=2/n=32 compiled
against exact 5ec, but `test-backend-ops` marked each `not supported [CPU]` and
reported 0/0 tests on Vulkan0. Therefore the cases neither failed numerically
nor exposed the intended route. D2 remains closed until a runnable reference
oracle and route assertion are planned; no full-parity patch or candidate image
was produced.

**Minimum GREEN surface.** Replace the rejected rounding-only patch with one
auditable parity patch against the pinned commit. Touch only:

- `quantize_q8_1.comp` for `127/amax` and CUDA-compatible half-away rounding;
- the Q8_0 x Q8_1 branch in `mul_mmq_funcs.glsl` for CUDA's final multiplication
  order; and
- the four ordinary/ID MMVQ/MMQ `qy_needs_dequant` predicates in
  `ggml-vulkan.cpp` so contiguous pre-quantized Q8_1 stays on its native route.

Regenerated shader artifacts are build output, not separately hand-edited
source. Do not import D094's unused `f16_round`, MTP device-handoff default,
CUDA rewrites, flash-attention staging, concat shader, split/geometry knobs,
dual-GPU scheduler changes, diagnostics, or fork documentation. Build a test
image and server image labelled with source commit and patch identity.

**Verification.** Focused: the targeted backend-op test passes on Vulkan and
shows the direct Q8_1 route; the existing quantization tests pass; the patch
applies cleanly to only the declared files. Broader: run the normal Vulkan
backend-op suite once, start the candidate server, load both target and draft
models, and complete one valid DFlash response. Keep the test binary in an
ephemeral build stage; do not add a deployed diagnostic executable.

**Dependencies, owner, rollout, rollback.** Owner: llama.cpp parity patch;
Servarr owns its reproducible builder. Depends on S0, not D1. Rollout is only the
isolated benchmark container. Rollback selects the unmodified pinned 5ec image;
the rejected rounding-only report and patch remain historical evidence.

#### D2.2 — uninstrumented generic attribution A/B

**Scenario and observable.** Run the D2 candidate and its unmodified 5ec control
through S0 without profiling. Evaluate DFlash n=2/n=3 and MTP n=2/n=3 in both
orders. DFlash is the target workload; MTP is the non-DFlash control proving the
change is reusable Vulkan work rather than a DFlash-local edit.

**RED.** The unmodified control versus the retained rounding-only image exits
non-zero under the S0 comparator. Expected reason: the n=3 TG confidence interval
is not positive.

**GREEN and verification.** Run the same command with the complete parity image.
Every response and fingerprint check must pass. Each width/family report remains
separate; a losing family or width is not hidden by an aggregate average. A
candidate reaches publication only when the paired TG 95% lower bound is above
zero for all declared promotion rows and production health is restored. A
numerically correct but neutral or slower patch is retained as evidence and not
published for production.

**Dependencies, owner, rollout, rollback.** Owner: Servarr evaluation. Depends
on D2.1 and S0. No compose edit occurs. The S0 trap and explicit post-run health
gate are the rollback.

#### D2.3 — leaf-first candidate publication

This slice opens only after D2.2 passes. It makes the tested artifact reusable;
it does not change production.

**RED.** The local candidate tag has no registry digest and therefore cannot be
used by a consumer. Publication metadata validation must fail before push.

**Minimum GREEN surface.** Land the patch artifact, provenance, build recipe,
benchmark evidence, and candidate label contract first. Publish the exact tested
image to
`harbor.homelab.pastelariadev.com/library/llama-server-vulkan` with source and
patch labels, resolve its immutable digest, and update the benchmark record and
this proposal with that digest and verdict. No compose file changes.

**Verification and rollback.** Pull the digest by hostname into an isolated
container, rerun one fixed DFlash request, and prove the local bytes match the
published digest:

```sh
cd /home/erik/Documents/erik/servarr
python3 -m unittest machines/orion/tests/test_benchmark_runners.py
ssh -o IdentityAgent=none orion 'podman pull <published-image>@sha256:<digest>'
```

Rollback removes only the isolated benchmark container and restores production
health. Never delete the published candidate or raw evidence during rollback.
Before production can consume it, return through `$pl`/`$ip` to choose one
single-lane transition: a measured DFlash decoder switch on a controlled base,
or a parity-patch backport onto the exact b10398/MTP production source.

#### D2.4 — same-image Vulkan integer-dot route screen

**Scenario and observable.** Bind the existing generic llama.cpp Vulkan
scenario with one runtime-only candidate. Control and candidate use the exact
same 5ec profile image, target/draft artifacts, flags, driver, prompts, seed,
and n=2/n=3 order-swapped matrix. Only the candidate sets
`GGML_VK_DISABLE_INTEGER_DOT_PRODUCT=1`; every report records that toggle.

**RED and GREEN.** The Servarr runner contract first failed because no fixed
same-image toggle mode or report field existed. Minimum GREEN adds only
`--compare-vk-int-dot <image> <dflash|mtp>` to `spec-matrix.sh` and
`experiment.runtime_toggle` to `benchmark.sh`. The mode rejects any other
family before SSH and does not accept arbitrary environment names or values.
No llama.cpp source, image, shader, model, compose file, or production flag is
changed.

**Verification and decision gate.** Local unit tests and shell syntax must pass.
Run DFlash first against the exact existing image:

```sh
cd /home/erik/Documents/erik/servarr
bash machines/orion/scripts/spec-matrix.sh --compare-vk-int-dot \
  localhost/llama-server-vulkan:dflash2-profile-5ecbe1ac dflash
```

The runner uses hostname-only `orion`, isolated port 8081, both orders, and the
existing cleanup/production-health trap. If either width lacks a positive TG
95% lower bound or any response check fails, retain the negative result and
close D2.4 without running MTP. If both widths pass, repeat with `mtp`; only two
passing family reports support a reusable Vulkan claim. Acceptance and prompt
throughput remain reported, never hidden by the TG verdict. Publication and
production remain separate gates.

**Ownership and rollback.** Servarr owns the runner and raw evidence. Upstream
llama.cpp owns both existing Vulkan routes. Rollback is automatic container
removal plus explicit health recovery of `llama-chat`; no artifact or host state
is mutated.

**Execution result — 2026-08-21.** Rejected. All 72 requests passed, reports
used one image ID (`8e207d8215521a5038d8ad3ae3d1b94369f325a62de6f32d8da007911b8b77e6`)
and exact revision 5ec, and toggle metadata distinguished candidate from
control. At n=2, candidate TG averaged 49.77 versus 53.82 control (-7.53%) and
acceptance fell 3.46 percentage points. At n=3, candidate TG averaged 49.82
versus 53.33 control (-6.58%) and acceptance fell 1.31 points. Paired mean TG
deltas were -4.05 tok/s (95% CI -7.34 to +0.25) and -3.51 tok/s (95% CI -9.05
to +2.23). Both promotion gates failed, so MTP was correctly skipped. The
benchmark container was absent afterward and production health returned `ok`.
D2.4 is closed; the runner and raw negative evidence remain reusable.

### Plan grill

Two bounded grill rounds were sufficient.

- Anti-consensus rejected “D094 worked on another machine, so port the commit.”
  Its mixed MTP, flash-attention, concat, diagnostics, and dual-GPU surfaces
  cannot support attribution on Orion.
- Assumption audit found two load-bearing facts: the pinned PR revision moved,
  and upstream Vulkan already has a timestamp logger but omits graph names. The
  plan freezes 5ec and adds only an opt-in name prefix.
- Pre-mortem found likely false wins from wrong-container fingerprints,
  aggregate averages hiding n=3 loss, profiling overhead, and cleanup that
  starts but never health-checks production. S0 and the uninstrumented final A/B
  close each path.
- Boundary review keeps D1-local work, reusable Vulkan work, and driver work
  separate. D3 remains unopened.
- CodeHero security/reliability review requires pinned source, traceable patch,
  labelled and digest-pinned publication, no environment dump, trap recovery,
  and explicit health. Performance/test review requires named dispatch timing,
  strict targeted backend cases, a non-DFlash control, and no profiled promotion.
  Compatibility/operability review preserves the production flags and makes PR
  refresh a later gate. Accessibility remains not applicable.
- Simplicity review removed a custom `dump_nextn` binary, a Gherkin runtime, a
  new profiler, external statistics packages, and premature DFlash optimizer
  branches.
- The second-round deployment pre-mortem found that pinning 5ec/DFlash over the
  b10398/MTP incumbent would change source base, decoder family, and parity patch
  together. Production compose edits were removed; this plan ends at immutable
  candidate publication and requires a later single-lane rollout contract.

The D1.3 continuation needed one bounded grill round:

- Anti-consensus rejected optimizing the largest name in the retained Vulkan
  map: the logger fences graphs and its frequency-128 output is not bounded to
  the draft call.
- Assumption audit verified in exact 5ec that
  `llama_get_embeddings_nextn()` already synchronizes, while Vulkan perf logging
  waits on a fence. An added production synchronization would duplicate existing
  behavior and cannot be the optimization.
- Pre-mortem separated an unfenced full-length lifecycle run from a short fenced
  dispatch probe; otherwise profiler overhead could become the claimed gain.
- CodeHero security is unchanged: pinned source/image, no secrets, hostname-only
  access. Reliability and operations retain trap recovery and health checks.
  Performance requires no logger in lifecycle measurements; tests require
  malformed-marker and decreasing-counter failures. Compatibility freezes 5ec;
  accessibility remains not applicable.
- Simplicity review rejected a new tracing API, external GPU profiler, general
  event schema, and conditional optimizer branches. Existing timers, markers,
  logger, parser, and unittest are sufficient.

The D1.4 planning return needed one bounded grill round:

- First-principles trace followed `result_output` through `ggml_top_k`, unary
  gather, selector scoring, and `dflash2_lattice`; the tensor is semantic input,
  not dead output.
- Cross-examination rejected “grounded on CUDA” as sufficient for fusion: CUDA
  implements only a separate top-k over materialized F32 logits.
- Pre-mortem rejected silently using `d2t`: a different candidate vocabulary
  can change acceptance and requires a compatible checkpoint.
- Simplicity and ownership review closed D1 instead of creating a new generic
  ggml operation inside a DFlash-specific slice.

The D2.4 revision needed one bounded grill round:

- Alternatives review chose the existing fixed runtime switch over a fused op,
  shader patch, image rebuild, or arbitrary environment interface.
- Assumption audit retained conflicting upstream evidence; the switch is a
  hypothesis until Orion's order-swapped n=2/n=3 result passes.
- Pre-mortem requires the same image on both sides, explicit toggle metadata,
  family validation before SSH, and the existing recovery trap.
- CodeHero security rejects arbitrary environment injection. Reliability and
  operations retain isolated startup and production health. Performance and
  tests require DFlash first, then MTP only after a positive screen.

## Out of scope

- n=4 or wider sweeps and automatic width selection.
- Multimodal requests and parallelism above 1; upstream reports identify gaps in
  both areas that need separate contracts.
- Windows, AMD proprietary Vulkan, dual GPU, or wholesale fork deployment.
- ROCm production migration.
- Host Mesa/kernel replacement or upstream driver work without a minimal
  application-independent reproducer.

## Frontier

S0 and D1.3 attribution are implemented; D1 remains closed after source audit.
D2.4's same-image integer-dot route is implemented and rejected on Orion, so MTP
was not run. D2.1's shader work and D2.3 publication remain closed. No unblocked
llama.cpp implementation lane remains. The driver lane opens only after an
unchanged-binary Mesa A/B and minimal reproducer identify RADV/ACO as the owner.

## Sources

- [DFlash2 llama.cpp PR 27342](https://github.com/ggml-org/llama.cpp/pull/27342)
- [DFlash2 graph at pinned commit](https://github.com/z-lab/llama.cpp-fork/blob/5ecbe1ac17ec0484c5b44af0bd580cdc9c428ed4/src/models/dflash.cpp)
- [CUDA top-k implementation](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-cuda/top-k.cu)
- [AMD Q4_K integer-dot route report](https://github.com/ggml-org/llama.cpp/discussions/18647)
- [RDNA4 Vulkan optimization sweep](https://github.com/ggml-org/llama.cpp/discussions/21043)
- [CUDA q8_1 quantization](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-cuda/quantize.cu)
- [CUDA Q8_0 x Q8_1 dp4a](https://github.com/ggml-org/llama.cpp/blob/master/ggml/src/ggml-cuda/mmq-vec-dot.cuh)
- [llama.cpp-rdna-lab](https://github.com/MrLordCat/llama.cpp-rdna-lab)
- [Mesa RADV documentation](https://docs.mesa3d.org/drivers/radv.html)
- [Mesa RADV environment variables](https://docs.mesa3d.org/envvars.html#radv-driver-environment-variables)
- [AMD RDNA performance guide](https://gpuopen.com/learn/rdna-performance-guide/)
