# Hermes — Deferred Improvements (backlog)

**Status:** Backlog (tracked, not scheduled). **Date:** 2026-06-29.
**Consolidates** the still-open items scattered across:
`2026-06-24-hermes-memory-skills.md` §9, `2026-06-25-hermes-deferred-plans.md`,
`2026-06-25-hermes-agentmemory-integration.md`, `2026-06-26-hermes-native-llm-wiki.md`.
Those docs' *resolved* items are superseded by the as-built `docs/hermes-llm-wiki.md`.

## What's live (not in scope here — done)
Native git LLM wiki on the vault `hermes` branch; base sessions retrieve-only
(all tools); a daily `wiki-consolidate` cron (glm-5, `[terminal]` only, 04:00)
promotes distilled built-in memory + `inbox.md` → wiki pages, lint, commit+push,
ntfy summary. Declaratively bootstrapped (sops deploy key + clone oneshot + cron
seed) → survives reprovision. **Validated unattended** (`85dc3ba`, 06-29 04:02).
agentmemory stopped. Each item below is an *improvement on top of* this.

---

## P1 — Security: sandbox the agent (`terminal.backend: docker`)
**Now:** `terminal.backend: local` + `HERMES_YOLO_MODE=1` + `approvals.mode=off`
→ the agent runs unsandboxed as the container user with the wiki + a (scoped)
push key, reachable via SWAG. The hardcoded catastrophic floor is the only guard.
**Want:** `terminal.backend: docker` so shell runs in a throwaway sandbox.
**Cost:** the container must spawn sibling sandbox containers (docker socket /
DinD) — non-trivial; the OCI module + image need wiring. Evaluate vs the
now-reduced exposure (SWAG-only ingress, scoped key, branch-isolated wiki).
**Trigger:** before widening the agent's reach or exposing it beyond the tailnet.
*(Source: §9.4 / deferred §3c — the one real open security item.)*

## P2 — Promote: review + merge `hermes` → `main`
The wiki now has real content (memory-architecture, homelab-fleet,
litellm-gateway, kindle-dashboard, voice-assistant, slm-data-discovery). Eyeball
the `hermes` branch in Obsidian/GitHub; establish a cadence (weekly?) to merge
trusted pages into `main` so they join the human vault. Until then `main` and
`hermes` diverge silently.
**Effort:** low (review + merge). **Trigger:** once you've judged page quality.

## P3 — Reliability: harden the ingest trigger
Capture today is **soft** — the SOUL directive *asks* base sessions to drop
durable bits to `inbox.md`; the model may not. Options for a **hard** trigger:
`on_session_end`/`on_session_finalize` hook that runs a tiny "anything worth an
inbox line?" pass on the just-finished session (in-context, cheap). Makes capture
deterministic rather than model-discretion.
**Effort:** medium (a hermes plugin hook). **Trigger:** if the wiki stops growing
(sign capture is being skipped).

## P4 — Tokens / observability
- **Lower memory caps.** `memory_char_limit/user_char_limit` are still 10000/3000
  — raised speculatively. The wiki is now the curated layer and built-in memory
  is just the cron's cheap *source*, so the per-turn memory injection can drop
  (e.g. 4000/1500) to reclaim base-session tokens. *(deferred §2.)*
- **Enable observability.** The Langfuse plugin is **off** → no model-call
  tracing. Enable it (or litellm's callback) so per-turn cost is measurable
  instead of inferred from request dumps. *(§9.3.)*

## P5 — Reproducibility / correctness
**Completed 2026-07-21.** Discovery's three Hermes containers pin
`nousresearch/hermes-agent@sha256:229429fe176efa05ca4e542a7e11348482b40c36f903191498c7016f1dfc1019`.
`hermes-flake` 0.2.44 wires `enableHealthcheck` to systemd timers and resolves
the container bridge IP when ports are unpublished. Deployment and one full
timer cycle passed with all containers running and no failed units.

## P6 — Memory architecture: agentmemory "unified approach"
The richer long-term design (parked): re-integrate agentmemory as the
**raw-capture + semantic-search** layer that *feeds* the wiki (hybrid recall +
knowledge graph), with hermes' cron curating its output into the human-readable
wiki. Full plan in `2026-06-25-hermes-agentmemory-integration.md`. Only revisit
once the native wiki has proven its value and you want semantic retrieval.
**Trigger:** when keyword/file recall over the wiki stops being enough.

## P7 — Hygiene
- **`hermes-skills` has no git remote** — rsync-only to discovery; no off-host
  backup/versioning. Add a remote (or fold into an existing repo).
- **rtk is installed but idle** (proven never to fire — base agent uses
  `execute_code`, not the terminal tool). Decide: rip out the plugin/skill/mount,
  or keep as dormant. *(§9.2.)*
- **`nix fmt`/alejandra formats gitignored `.devenv`** on commit (cosmetic, exit
  0). Scope the formatter to skip `.devenv` if the noise annoys.

---

## Priority call
P1 (sandbox) is the only item with real risk; everything else is value/hygiene.
Cheapest high-value: **P4 lower memory caps** (immediate token win) and **P2
merge** (surface the wiki). P6 (agentmemory) is the big strategic re-expansion —
defer until the simple native wiki proves itself.
