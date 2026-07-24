> ⏭ **SUPERSEDED 2026-06-29** by `2026-06-29-hermes-deferred-improvements.md` (consolidated, current). Kept for history.

# Hermes — Deferred Plans (backlog)

**Status:** Backlog (tracked, not scheduled)
**Date:** 2026-06-25
**Parent:** `2026-06-24-hermes-memory-skills.md` (§7 review, §8 OCI cutover)

Work intentionally NOT done in the memory/skills/OCI sessions. Ordered by
value. Each item names its trigger ("do this when …") so nothing here is a
standing obligation.

---

## 1. Memory backbone — `wiki-curator` + Dreaming  *(high value, high effort)*

The Reddit author's #1 unsolved problem and where the LLM-wiki pattern pays off
(proposal §4b/§4e). Upstream flat memory (agent-curated notes) is low-signal
until a curation loop exists.

- **`wiki-curator` skill** — ingest / query / lint a git-tracked, 3-layer
  markdown knowledge base (raw sources → LLM-maintained wiki with
  `[[wikilinks]]` + `index.md`/`log.md` → schema doc). Emits Obsidian-compatible
  markdown (no plugin needed — produce the vault, skip the integration).
- **Dreaming cron** — nightly consolidation: read recent sessions → extract
  decisions/projects/bugs → write into the wiki, auto-loaded at session start.
  - **Use the native scheduler**, not an external systemd timer: the image has
    `cron/scheduler.py` + session hooks (`on_session_start/end/finalize/reset`).
  - **Bound the cost** — "read all conversations" against `/opt/data/sessions`
    on the shared LiteLLM budget can blow up. Cap the window / token budget.
- Memory lives under the `external_dirs` skills tree so it is versioned + shared
  laptop↔gateway.

**Trigger:** after the OCI cutover is stable and Langfuse shows headroom.

### Grounded design — verified against the running image (2026-06-25)

The primitives all exist; the open choices are design, not feasibility.

- **Dreaming = a native cron job.** `cron/scheduler.py` runs an internal ticker
  (heartbeat confirmed live) that spawns an agent per due job, with an `approve`
  auto-mode, **per-job `enabled_toolsets`**, and a **pinnable model**. No
  external systemd timer needed.
- **Cron jobs are runtime STATE, not declarative.** They live in
  `/opt/data/cron/` (created via the `cronjob` tool); the `cron:` config block
  only tunes the *scheduler* (provider/model defaults), not the jobs. → To fit
  repo→deploy, **seed the Dreaming job on boot** (a bootstrap step that creates
  it if absent) or accept it as restic-backed state. This is the main
  declarative gap.
- **Session reading must be bounded.** 108 × `/opt/data/sessions/session_*.json`,
  each `{…, system_prompt, tools, messages:[…]}`. Each file embeds its full
  system_prompt + tools (~15k+), so naive "read all" is enormous. Dreaming must
  read **`.messages` (user/assistant) only, since-last-run**, and **pin to MiMo
  (free)** — never glm-5 — so consolidation doesn't bill the response budget.
  Give the job `enabled_toolsets = [memory + read]` only.
- **Output target — THE decision:**
  - (a) **built-in `memory` store** (`/opt/data/memories/`, `MemoryStore.add()`,
    auto-injected every turn, capped 10000). Simplest; *actually loaded*. But
    flat, not git-versioned/reviewable — against §3's ethos.
  - (b) **git wiki** under the `external_dirs` skills tree + an `on_session_start`
    plugin hook (exists) to load it. Versioned, portable, Obsidian-viewable —
    but needs the load hook and risks the Reddit author's "generic store sits
    unused" failure.
  - Lean (a) for the loop to actually pay off (auto-injected = used); optionally
    have Dreaming *also* emit (b) as a reviewable artifact. Don't build (b) alone.
- **Caps interaction (#2):** Dreaming makes the auto-injected memory high-signal,
  which is the precondition for keeping caps at 10000 (kept) being worth it.

## 2. Re-evaluate §1 memory caps against Langfuse  *(cheap, do with #1)*

Caps were raised (10000 / 3000 chars) *before* curation existed — currently
paying ~+4.7k tok/turn for possibly-low-signal auto-notes. Once Dreaming/wiki
produces high-signal memory, measure real tok/turn in Langfuse and lower the
caps if the auto-notes are junk. Baseline + the trace to watch are recorded in
the parent doc §7.

**Trigger:** when #1 lands (caps and curation are coupled).

## 3. rtk  *(REJECTED — doesn't fire on this agent; see parent §9.2)*

**Resolved 2026-06-25: rtk does not work for this deployment.** Binary is on the
container PATH (OCI store-mount), the `rtk-rewrite` plugin loads, the skill is
shipped — and rtk **never fires** (`rtk gain` empty, 0 rewrites after real
turns). Root cause: rtk only hooks the `terminal` tool, which the default
gateway posture doesn't expose — the agent runs shell via `execute_code` (python
sandbox / raw subprocess), bypassing rtk. The only reliable fix
(`agent.disabled_toolsets=["code_execution"]`) was declined (loses the python
sandbox). The instruction nudge (skill + SOUL line) was ignored by the model.

Plugin/skill/mount are installed but **idle dead weight** — kept by choice; rip
out any time with no functional loss. Note: the §7 claim "`pre_tool_call` can't
rewrite" was itself wrong — a *Python plugin* rewrites `args["command"]` in
place; it just never gets a terminal call to rewrite. Do **not** revisit rtk
unless the terminal toolset becomes the agent's shell path.

## 3b. Cut input tokens — the real lever  *(NEW — replaces the rtk premise)*

rtk targeted tool *output*, the smallest cost. Measured per-turn cost (parent
§9.3): tools array ~13k tok + SOUL ~4k + memory ~3k, and coding sessions add
~14k of verbatim CLAUDE.md injection. Actual reductions:
- **`agent.disabled_toolsets`** — drop unused toolsets (delegation/cron/browser/
  vision) → up to ~6k tok/turn off *every* turn. `delegate_task`+`cronjob` alone
  are ~1.9k each. (NOTE: cron is needed by #1's Dreaming plan — keep if pursuing.)
- **Trim/scope the coding-posture CLAUDE.md injection** (~14k in repo sessions).
- **Memory caps** kept at 10000/3000 by choice (#2); lower when curation exists.
- Measure via request dumps (`/opt/data/sessions/request_dump_*.json`, error-only)
  — **not** Langfuse (its plugin is off).

**Trigger:** when token budget bites; user must pick which toolsets are expendable.

## 3c. Security hardening of the OCI deploy  *(parent §9.4 — mostly DONE 2026-06-25)*

The cutover left a risky posture: redundant `0.0.0.0:8642/8644` host publish
**+** `terminal.backend: local` (unsandboxed) **+** `HERMES_YOLO_MODE=1` +
`approvals.mode=off`. Status:
- ✅ **Host port publish dropped** — `publishPorts=false` (new hermes-flake oci
  option); verified host port gone, SWAG still 200 over homelab-net.
- ✅ **No-op firewall line removed.**
- ✅ **Dead sops keys pruned** (now 5 live: OPENAI/API_SERVER/EXA + bare
  TELEGRAM/DISCORD).
- ⏳ **`terminal.backend: docker` (sandboxed)** — STILL OPEN. With YOLO on, the
  agent runs commands unsandboxed as the container user with `/opt/data` +
  homelab-net reach. SWAG is now the only ingress (key+TLS), so the blast radius
  needs a leaked API key or a compromised on-net container — lower, but
  sandboxing is the remaining hardening. Note: `backend: docker` needs the
  container to spawn sibling sandbox containers (docker socket) — non-trivial;
  evaluate cost vs the now-reduced exposure.

**Trigger:** evaluate `backend: docker` when convenient; the acute LAN exposure
is closed.

## 4. Pin the image to a digest  *(hygiene)*

The OCI module runs `nousresearch/hermes-agent:latest`. Under oci-containers
`:latest` is NOT auto-repulled (unlike compose `pull_policy: always`), so a
moving tag gives neither reproducibility nor upgrades. Pin a digest
(`…@sha256:…`) and bump deliberately.

**Trigger:** first deliberate version bump after the cutover settles.

## 5. Re-scope §4d "Feedback Loop"  *(design correction)*

The proposal's §4d ("agent updates its own system prompt") conflicts with the
locked decision that **SOUL stays `:ro`/declarative** (parent §7). If a
self-improvement loop is wanted, it must write a *separate* `learned-*.md` under
the skills/memory tree, never SOUL. Fold into #1 (the wiki is the natural home
for learned facts).

**Trigger:** only if a self-improvement loop is actually desired; otherwise drop.

## 6. §6 community repos — none adopted  *(reference only)*

`0xNyk/awesome-hermes-agent` picks (Mnemosyne, oh-my-hermes, hermes-eval, abvx,
sourcevault) are a reference list, not a plan. The Reddit author's own lesson —
*one file / one job / no deps; self-built beats downloaded; generic integrations
sit unused* — argues against adopting the buffet. Every one is third-party code
in a `YOLO_MODE` + terminal container on the homelab net (parent §6 security
caveat). The `rtk`/`caveman` community-repo claims were already disproven (their
`pre_tool_call`-rewrite mechanism doesn't exist in this image).

**Trigger:** adopt at most ONE, only after the core loop (#1) proves stable, and
only after vetting + pinning the source. `hermes-eval` becomes relevant only
once the skill count justifies regression testing.

---

## Not in scope (explicitly dropped)

- Obsidian *integration* (Hermes Console plugin) — produce an Obsidian-viewable
  vault via #1 instead; skip the plugin (it "sits unused").
- Passive note stores / generic knowledge dumps — invest in the active
  Dreaming+wiki loop, not a store nobody reads.
