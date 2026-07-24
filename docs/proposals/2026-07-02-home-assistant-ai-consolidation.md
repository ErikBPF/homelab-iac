# Home Assistant + AI — consolidated plan

**Date:** 2026-07-02
**Status:** Proposal (structure + synthesis drafted; decision gates `TODO(erik)`
open) — consolidates the shipped voice-assistant core, external reliability
research, the open §6/A12 synergy backlog, and a fine-tuned local tool-caller
track derived from the `~/Documents/erik/slm` POC. **RFC judgment is human**
(per `CLAUDE.md`); this doc assembles evidence and frames the forks, it does not
make the calls.
**Owner:** erik
**Target hosts:** `discovery` (HAOS + LiteLLM), `kepler` (STT/TTS/embed/vision),
`orion` (reasoning LLM), plus a candidate small-model host (see §5).
**Related:**
[`../implemented/2026-05-27-home-assistant-voice-assistant.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-05-27-home-assistant-voice-assistant.md)
(the shipped core), [`2026-05-23-home-assistant-declarative.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-05-23-home-assistant-declarative.md)
(implemented config-management workflow; A11 resolved),
[`2026-07-02-open-decisions-and-work.md`](2026-07-02-open-decisions-and-work.md)
(backlog A12 — this doc is the "RFC próprio" A12 asks for),
[`../reference/kepler-ai-serving.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/kepler-ai-serving.md)
(serving as-built).

> **Implementation update — 2026-07-14:** D-FT is no longer an open model
> question. Qwen3-4B with the v8 on-policy DPO adapter is the selected
> act-nothing shadow candidate. Offline shadow contracts and the reversible HA
> mirror have been implemented and tested, but Kepler deployment is paused at
> the capacity gate. Whisper leaves 4,178 MiB free after a real request; the
> 2.69 GiB GGUF plus Q8 KV, CUDA, and server buffers does not leave safe
> headroom. Move `bge-m3` from GPU to CPU and restore or deliberately retire the
> unhealthy F5-TTS/reranker services before repeating the concurrent capacity
> test. Do not enable real capture until that gate passes.
>
> **Topology correction — 2026-07-16:** the capacity sequence above was
> superseded when Kepler's complete AI-serving stack was intentionally retired
> on 2026-07-14. Do not restore that general stack or treat Whisper,
> embeddings, reranking, or TTS as resident dependencies. No replacement
> runtime is approved.

---

## 1. Purpose

One place that answers: *what is our Home-Assistant-with-AI, what makes it
reliable, and is a fine-tuned small model worth building for home agentic
calls?* It merges four inputs:

1. **Shipped core** — the PT-BR LiteLLM-routed voice loop (Phases 0–3 live).
2. **External reliability research** — the HA-community "reliable & enjoyable
   locally-hosted voice assistant" journey.
3. **Open synergy backlog** — §6 of the voice-assistant doc, tracked as A12.
4. **`slm` POC advancements** — a homelab teacher-trace → LoRA → LLM-judge
   pipeline, its hardware learnings, and its (blunt) research on the
   small-model tool-calling floor.

**Invariant carried forward (non-negotiable):** Home Assistant's *only* model
egress is the **LiteLLM gateway** on discovery. STT, TTS, LLM, vision,
embeddings, and any future local tool-caller are reached through a LiteLLM
route — never a direct-to-host port. This is what keeps Langfuse tracing, key
scoping, budgets, and fallback routing working. Any new backend = a new
`model_list` entry, not a new HA→host connection.

---

## 2. As-built (what already works)

Source of truth:
[`../implemented/2026-05-27-home-assistant-voice-assistant.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-05-27-home-assistant-voice-assistant.md)
and [`../reference/kepler-ai-serving.md`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/kepler-ai-serving.md).

| Layer | Model / service | Host | LiteLLM route |
|---|---|---|---|
| Wake word | openWakeWord (server-side) + M5Stack Atom Echo | discovery / .109 | — |
| STT | faster-whisper `large-v3-turbo`, `lang=pt` | kepler:9000 | `whisper-pt-br` |
| TTS (primary) | edge-tts `pt-BR-ThalitaMultilingualNeural` `+25%` | kepler:8002 | `tts-pt-br` |
| TTS (offline) | piper `pt_BR-faber-medium` | kepler:8003 | `tts-pt-br-piper` |
| Brain | Qwen3.6-35B-A3B MoE (llama.cpp, Q4_K_M) | orion:8080 | `qwen-chat` |
| Embeddings | BAAI/bge-m3 (TEI, 1024-dim) | kepler:8085 | `bge-m3` |
| Vision | Gemma 4 E4B (llama.cpp) | kepler:8082 | `vision-qwen2vl` **DISABLED** |

- **Brain wiring:** `custom-conversation` (michelle-avery), HA Assist LLM API
  exposed for device control, **prefer-local-intents ON**.
- **Fallback (Decision #3):** orion down → HA built-in intent engine
  (deterministic sentence matching) only; free-form Q&A fails gracefully in
  PT-BR. **Device control degrades to whatever the built-in intents + custom
  sentences cover — nothing fuzzier.**
- **Vision is dead** since 2026-06-29: Gemma-VL co-resident with the embedder
  overcommits kepler's 8 GB (embed `/v1/embeddings` hangs). Route is dead until
  a GPU/serving fix (see `kepler-ai-serving.md` History).

---

## 3. Reliability gap — external research vs. our stack

From the HA-community "reliable & enjoyable locally-hosted voice assistant"
journey (llama.cpp + high-quant GGUF, iterative prompt work, entity
discipline). Mapped to us:

| Reliability lesson (external) | Our state | Verdict |
|---|---|---|
| llama.cpp + **high-quant** GGUF, not Ollama `:4b` defaults | orion llama.cpp Q4_K_M 35B-A3B | ✅ correct tier |
| **20–30B MoE / 9B dense** hits 1–2 s and is reliable | 35B-A3B MoE | ✅ in the reliable band |
| **Cap exposed entities (~32)**; group the rest; context window is the hard limit (one report: 53 entities broke a 14B) | **exposed-entity count not audited** | ⚠️ **top suspected reliability risk** |
| **The prompt makes or breaks it** — per-service `#` sections, strict format rules (no markdown/emoji), example outputs, `"*"` for false activations, "repeat that?" for garbled short input | single PT-BR persona prompt | ⚠️ **thin vs. the structured spec** |
| Hybrid: **sentence-automation triggers** for complex features (music), LLM for device control | built-in intents + LLM only | ⚠️ no automation layer for complex asks |
| Custom wake word (microWakeWord, ~30 min GPU) | default "Okay Nabu" | optional polish |
| Newer options: Qwen3-ASR STT, Kokoro TTS | whisper-turbo / edge-tts | fine; revisit only if quality complaints |

**Committed track (no decision needed — bank these regardless).** Both are
`home-assistant-config` PR edits, zero new infra, and address the two ⚠️ risks
most likely to be limiting reliability today:

- **R1 — Entity audit + cap.** Enumerate entities exposed to Assist; group /
  unexpose down toward the ~32 band; confirm the count against orion's context
  budget. Verify: fewer entities in the Assist "exposed" list; spot-check that
  common commands still resolve.
- **R2 — Structured prompt rewrite.** Rework the PT-BR system prompt into the
  external playbook's shape: per-service `#` sections, explicit spoken-style
  format rules, false-activation `"*"` handling, garbled-input "pode repetir?".
  Verify: A/B a fixed command set (device on/off, scene, a question, a garbled
  clip) before/after; no regressions, fewer spurious replies.

---

## 4. The fine-tune question — evidence from `slm`

`~/Documents/erik/slm` is a learning-first POC on **data-contract discovery**
(prose Q&A + citation), **not** tool-calling. But its pipeline, hardware
findings, and research transfer. The blunt facts:

**Research (the repo's own digests):**
- **Tool-calling size floor** (`docs/research/reddit-practitioner-digest.md` §5):
  `<7B tool-calling essentially vanishes; 8B = single tool call; 14B+ = reliable
  multi-step.` Llama-3B ≈ 0 % tool invocation across 9 tasks. Best small
  function-callers: **Qwen3-8B / Qwen2.5-7B** (Hermes `<tool_call>`),
  **Llama-3-Groq-Tool-Use-8B** (89 % BFCL), mistral-nemo 12B.
  **Phi-4-mini 3.8B** has native function calling (MIT, 128k).
- **`CodeAgent` (write Python) > JSON tool-calling for small models.**
- **Distillation ceilings at the teacher** (`deepseek-papers-survey.md`):
  distilling *from* the 35B → matches, never beats it. Surpassing needs a
  stronger teacher (Opus) + your own RL on the student.
- **Doctrine** (`slm-landscape-2024-2026.md`): *RAG = knowledge; fine-tune =
  behavior / output format / **tool-call shape**.* Fine-tune only to lock in a
  strict output envelope — endorsed, never built.

**Proven results (real numbers, provisional — N≈13, single judge):**
- Distilled **Qwen3-4B matched the served 35B** on the narrow single-turn task
  (citation 1.00, correct-pick 13/13) — but only because that task is *easy*
  (prose + one citation), far below argument-filled multi-tool calls.
- **Decode discipline is the biggest quality lever:** greedy +
  `repetition_penalty=1.15`, `enable_thinking=False`, **no `max_new_tokens`
  cap** (capping → truncation + hallucination). Sampling on ≤4B →
  hallucinated identifiers + language leakage. **Greedy is mandatory at 4B.**

**Hardware playbook (as-built in `slm`):**
- Train on **kepler CUDA** (RTX 3070 8 GB — bnb 4-bit works, QLoRA of ≤3B fits)
  or **cloud A100** for anything ≥7B.
- **orion RDNA4/gfx1201 (RX 9070 XT, 16 GB): bnb-4bit is BROKEN**
  (`invalid device function` — HIP kernels not built for wave32 RDNA4). Only
  **fp16 LoRA on ≤4B** works, via a slim container + pip torch-rocm to
  `/scratch` (never touch orion's podman storage — it would orphan the running
  llama.cpp servers). Untried fallbacks: torchao int4, build bnb from source,
  GPTQ/AWQ, cloud A100.
- **Reusable recipe** (`experiments/004-answer-distill-9b/`): `gen_traces.py`
  (teacher decode temp 0.2, incremental write) → `train_sft.py`
  (QLoRA `r=16, α=32, dropout=0.05, all-linear`, lr 2e-4, grad-accum 8, bf16,
  grad-checkpoint, maxlen 2048, 1–2 epochs) → `infer_tuned.py` (greedy + rep
  penalty) → LLM-as-judge, with **deterministic verifiable scoring first**
  (schema-valid? correct entity_id?) and judge only for the NL confirmation.

### 4.1 Where a fine-tune actually earns its keep here

It does **not** replace or beat the 35B brain — the 35B is already in the
reliable tier, and a small student can at best match its teacher. The single
defensible niche is the **Decision #3 offline gap**:

> Today, orion down = deterministic HA intents only. A small **always-on local
> tool-caller**, fine-tuned purely for **device-control tool-call shape** over
> the (capped, ~32) exposed entities, would let *paraphrased / fuzzy* commands
> still control the house when the 35B is offline — without waking orion.

This is narrow + single-turn = the *one* regime `slm`'s own floor says a ≤8B
tune can win ("narrow tasks — classification, function-call shape — *can* be
won by a 1B tune"). It is genuinely useful (resilience) and bounded. It is also
real, new work: `slm` has **no** tool-call-JSON traces, no schema-validated
tool eval, no multi-turn loop — all of that is built fresh.

**Risk to weigh:** even single-call tool use wants ~8B; a 4B may need heavy
data + constrained/grammar decoding to be trustworthy. Model candidates that
respect the floor: **Qwen3-8B**, **Phi-4-mini 3.8B** (native FC),
**Llama-3-Groq-Tool-Use-8B**. VRAM: kepler 8 GB is already contended (embed is
24/7); orion 16 GB has room but Vulkan-serves and ROCm-trains painfully. A
`model_list` route + host placement is a real decision, not a footnote.

---

## 5. Decision gates — `TODO(erik)` (RFC judgment is human)

The committed R1/R2 track (§3) proceeds regardless. Everything below is a
human call; nothing here is locked.

- **D-FT — Fine-tune track scope.** One of:
  - **(a) Offline tool-caller** *(drafter's lean)* — build the small
    device-control tool-caller of §4.1 as the orion-offline resilience layer.
    Bounded, useful, respects the size floor if we pick an ~8B base.
  - **(b) Research spike only** — write the trace-gen + schema-eval harness,
    measure a 4B/8B tune against the 35B on a held-out device-command set, and
    **do not enter the production path unless it beats the RAG/35B path**
    (`slm` RFC 0005 guardrail). Decide after numbers.
  - **(c) Skip** — don't fight the floor; ship R1/R2 + a hybrid
    sentence-automation layer for complex asks (music), keep `slm` techniques
    on the data-contract side only.

- **D-FT-model / host** (only if D-FT = a or b). Base: Qwen3-8B vs Phi-4-mini
  3.8B (native FC) vs Llama-3-Groq-Tool-Use-8B. Train: kepler CUDA (≤3B QLoRA)
  vs cloud A100 (≥7B) — **not** orion bnb-4bit (broken). Serve: kepler (VRAM
  contended) vs orion vs elsewhere; add the LiteLLM route + a fallback ordering
  so HA prefers 35B, drops to the small local caller when orion is down.

- **D-SYN — §6/A12 synergies.** Backlog A12 says pick 0–2, the rest die.
  Ranked by value/effort with current constraints:
  1. **f5-tts voice clone** — backend already built (kepler:8001); cost is one
     `model_list` entry + a reference voice. **Low effort, ready.** (License:
     CC BY-NC fine-tune, or swap the Apache base.)
  2. **RAG memory + Alexa announcements** — `bge-m3` is already resident for
     semantic memory/RAG the assistant can cite; existing Echo `media_player.*`
     as announcement targets. **Low–medium, no new infra.**
  3. **Camera vision** — high value, but **blocked**: `vision-qwen2vl` backend
     is disabled (kepler 8 GB VRAM contention wedged embeddings). Needs a
     GPU/serving fix (move VLM to orion, or a bigger GPU) *before* it's viable.
  4. **hermes-MCP bridge** — most powerful (one brain for house + homelab) but
     **high effort**: hermes isn't a streaming Assist conversation entity, so
     it needs a bridge. Own RFC if pursued.

---

## 6. Phasing (once gates are decided)

1. **Phase A — Reliability hardening (committed, do first).** R1 entity
   audit/cap + R2 structured prompt rewrite in `home-assistant-config`. Verify
   per §3. This is the highest reliability-per-effort work and unblocks a clean
   baseline to measure any fine-tune against.
2. **Phase B — Synergies (per D-SYN).** Land the 0–2 chosen. f5-tts and
   RAG/Alexa are `model_list` + config edits; camera vision only after a VLM
   serving fix.
3. **Phase C — Fine-tune (per D-FT).** If (a)/(b): fork `slm`'s
   `gen_traces/train_sft/infer_tuned/judge` scripts; author tool-call-JSON
   traces from a Claude/Opus teacher over the capped entity set; schema-validated
   eval (tool exists? args valid? correct entity_id?); train on kepler-CUDA/A100;
   greedy + rep-penalty decode; gate on beating HA built-in intents on the
   offline command set before wiring the LiteLLM fallback route.

---

## 7. Open questions

- **R1 unknown:** how many entities *are* exposed today? Audit is step one — the
  whole reliability story hinges on it.
- **Fine-tune vs. hybrid automations:** for the offline-resilience goal, is a
  fine-tuned tool-caller actually better than expanding HA custom-sentence
  intents (deterministic, zero-GPU, always-on)? The intent route may cover the
  common commands cheaply — measure before training.
- **VLM revival cost:** camera vision needs the VLM off kepler's contended
  8 GB. Is orion Vulkan-serving a VLM acceptable, or does it wait for a GPU?
- **Small-model serving slot:** where does an always-on ~8B tool-caller live
  without starving embeddings or the 35B? This may itself gate D-FT.

---

## 8. Shadow-stack implementation checkpoint — 2026-07-14

This section supersedes the older speculative fine-tune and host-placement
language above. It exists so a fresh operator can resume without reconstructing
the experiment history.

### Selected candidate and boundary

- Base: Qwen3-4B.
- Adapter: v8 on-policy DPO, 1,536-token maximum sequence.
- Serving artifact: Q5_K_M GGUF with Q8_0 K/V and entity-enumerating GBNF.
- Frozen-116 constrained exact: 0.871; zero hallucinated entities.
- Measured candidate latency on Orion: 523 ms p50, 662 ms p95.
- Incumbent HA/Whisper path remains authoritative.
- Candidate receives no HA credential and has no dispatch capability.
- Real HA adoption remains transcript mirroring only; no conversation-agent
  replacement or live canary is approved.

### Implemented, not deployed

The shadow runtime now has tested contracts for:

- immutable, schema-validated capture events;
- bounded non-blocking queueing with recorded saturation drops;
- authenticated versioned capture API, payload limits, and path traversal
  rejection;
- encrypted-mount enforcement for the local SQLite evidence store;
- raw transcript/audio exclusion from external telemetry;
- immutable model, grammar, snapshot, prompt, and harness cohort hashes;
- deterministic session-level 60/40 train/escrow assignment;
- five-minute satellite-wide validated-target memory with per-request opt-out;
- GPU, thermal, corrupt-trace, queue, and incumbent-latency circuit breakers;
- manual pause and selective evidence deletion;
- candidate replay through an act-nothing Rust harness that exposes no dispatch
  capability;
- separate counterfactual intent, harness safety, and verified household outcome
  fields;
- a fake candidate-to-harness-to-evidence end-to-end test.

The HA side has a tested reversible conversation proxy design. It forwards the
request synchronously to the current incumbent, returns the exact incumbent
result, and places the immutable shadow capture on a bounded asynchronous fork.
Timeout, crash, or saturation cannot delay or replace the incumbent result.
Rollback is reselecting the incumbent conversation entity. No live HA config was
changed.

Verification at this checkpoint:

- ha-agent Python suite: 118 passing;
- Rust harness suite: 98 passing;
- HA configuration suite: 11 passing;
- Python lint, HA component compilation, and patch checks passing.

### Capacity gate and current blocker

> **Superseded 2026-07-16.** This subsection records the pre-retirement
> measurement. It is not a resume procedure.

Kepler required a full cold power cycle after the RTX 3070 failed driver
initialization. GPU, CDI, and Whisper recovered afterward. Capacity measurement
then produced:

| State | VRAM used | VRAM free | Temperature |
|---|---:|---:|---:|
| Cold-boot baseline with GPU `bge-m3` | 1,373 MiB | 6,468 MiB | 46°C |
| After a real Whisper request | 3,663 MiB | 4,178 MiB | 53°C |

The candidate GGUF is 2,889,513,248 bytes and its expected SHA-256 was verified
on Orion. It was intentionally not copied or loaded on Kepler: Q8 KV, CUDA, and
llama-server buffers would leave an unsafe margin beside Whisper. F5-TTS and the
reranker were also unhealthy during the capacity run, so the full warmed-stack
baseline was not established.

### Resume sequence

> **Retired sequence.** Do not execute steps 1–7 below. They assumed the former
> Kepler AI-serving stack still existed and would be repaired in place.

1. Move `bge-m3` to its CPU image through the existing declarative Compose and
   systemd ownership path. Do not use an ad-hoc container.
2. Decide whether F5-TTS remains a supported resident service; repair it or
   disable it explicitly so capacity calculations describe the real stack.
3. Restore reranker health and verify incumbent routes before loading Qwen.
4. Repeat warm VRAM, thermal, Whisper latency, and concurrent Whisper/Qwen tests.
   Reject the layout on OOM, driver fault, thermal violation, or incumbent p95
   regression above 10% after at least 20 requests in ten minutes.
5. Only after the capacity gate passes, add separate llama-server and shadow
   worker containers on a private network. systemd owns lifecycle; no shared pod
   is required.
6. Validate restart persistence and run the containerized fake E2E. Prove that
   stopping or removing the shadow stack leaves incumbent HA healthy.
7. Enable the HA mirror only after all preceding gates pass. Keep the candidate
   act-nothing; supervised and autonomous canaries remain out of scope.
