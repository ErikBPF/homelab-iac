# Hermes memory backbone via agentmemory (git wiki) — PLAN

> ⏸ **DEFERRED 2026-06-26.** Pivoted to a native hermes LLM wiki first (no
> agentmemory) — see `2026-06-26-hermes-native-llm-wiki.md`. This agentmemory
> integration is parked for the later "unified approach"; the research/findings
> here remain valid. The party grill's multi-writer risk is why we start native +
> branch-isolated.

**Status:** Deferred (was: Plan — not deployed). Supersedes deferred-plan §1 (wiki-curator +
Dreaming): we **integrate the already-running agentmemory** instead of building
a curator + nightly cron from scratch.
**Date:** 2026-06-25
**Parent:** `2026-06-24-hermes-memory-skills.md` §9, `2026-06-25-hermes-deferred-plans.md` §1

## TL;DR
Erik already runs **agentmemory** (`rohitg00/agentmemory`) on discovery — a full
memory engine that does embeddings + hybrid search + **automatic 4-tier
consolidation + knowledge-graph extraction + Obsidian export**, with no external
scheduler. The proposal's wiki-curator/Dreaming is *reinventing it*. Plan:
1. Wire **hermes → agentmemory** as an MCP server (`npx -y @agentmemory/mcp`;
   the agent gets save/recall/smart-search/graph tools; agentmemory curates).
2. **Trial both** memory systems (built-in + agentmemory) A/B; disable built-in
   later if agentmemory wins (reclaims the ~10k-char/turn injection then).
3. Deliver the **git wiki** by exporting agentmemory into a discovery-side clone
   of `git@github.com:ErikBPF/vault.git` (scoped subdir) + commit/push timer.

## What's already there (verified on the live container 2026-06-25)
- `discovery/agentmemory:latest`, healthy, on `homelab-net`, REST on `:3111`
  (Bearer `AGENTMEMORY_SECRET`); MCP via the `agentmemory-mcp` stdio CLI.
- Env: `GRAPH_EXTRACTION_ENABLED=true`, `CONSOLIDATION_ENABLED=true`,
  `AGENTMEMORY_INJECT_CONTEXT=true`, `OBSIDIAN_AUTO_EXPORT=true`,
  `AGENTMEMORY_EXPORT_ROOT=/export` → host `/home/erik/backup/Documents/erik/obsidian`
  (`vault/`; **not yet a git repo**).
- The workstation already uses it via `~/.claude.json` mcpServers (CLI
  `agentmemory-mcp`, `AGENTMEMORY_URL=https://memory.homelab.pastelariadev.com`).
- hermes container **has node + npx** (`/usr/local/bin/{node,npx}`) and an
  `mcp_servers` config block → it can run the stdio MCP client.

## Architecture
```
hermes agent (OCI) ──MCP(stdio: agentmemory-mcp)──▶ agentmemory REST :3111
       │                                              │ (homelab-net, internal)
       │ save/recall/smart_search/graph_query         ▼
       └────────── auto consolidation + graph + Obsidian export
                                                      ▼
                              /home/erik/.../obsidian/vault  ──git──▶ git wiki
```

## Components (each a deploy step — NOT done yet)

### 1. hermes → agentmemory MCP (declarative, OCI module `settings`)
- Add to `services.hermes-agent-oci.settings.mcp_servers`:
  ```
  agentmemory = {
    command = "npx"; args = ["-y" "@agentmemory/mcp"];   # or a baked CLI
    env = {
      AGENTMEMORY_URL = "http://agentmemory:3111";        # internal homelab-net
      AGENTMEMORY_SECRET = "\${AGENTMEMORY_SECRET}";       # env indirection
    };
  };
  ```
- **Secret handling**: the rendered config.yaml lives in `/nix/store` (world-
  readable) — the secret MUST NOT be literal there. Add `AGENTMEMORY_SECRET` to
  the hermes sops `server_env` and reference `${AGENTMEMORY_SECRET}` (same
  pattern as `${OPENAI_API_KEY}`; verify hermes expands env in `mcp_servers`).
- **Internal URL** `http://agentmemory:3111` (homelab-net) — not the SWAG URL;
  no TLS/egress in-cluster.
- **npx vs baked**: `npx -y @agentmemory/mcp` fetches from npm on first run
  (egress + latency, then cached in /opt/data). Cleaner: bake/pin the CLI into
  the image or vendor it. Decide (see open questions).
- **MCP stdio vetting**: hermes disables "exfiltration-shaped" MCP stdio entries
  (`config.py` ~5233) — confirm agentmemory passes the allowlist.

### 2. Memory: run BOTH as a trial  *(decision: A/B, do not disable yet)*
- Keep hermes built-in memory (`memory_enabled=true`, caps 10000/3000) **and**
  add agentmemory via MCP. Compare signal before committing to one.
- **Cost during trial is a pure add** (built-in 10k injection stays + agentmemory
  MCP tool defs join the tools array). Accept for the trial; **measure** the
  added tool-token cost from a request dump.
- If agentmemory proves the better store, a later step disables built-in memory
  (the ~10k/turn token win from §9.3) — tracked, not done now.
- If the MCP tool defs are heavy, gate to a minimal subset (save/recall/
  smart_search) via hermes' MCP tool-gating (`config.py` ~2493/2509).

### 3. Git wiki transport — ALREADY EXISTS (verified 2026-06-25, nothing to build)
The loop is already wired; my earlier "discovery clone + push timer" was redundant:
- agentmemory (discovery) exports to `/home/erik/backup/Documents/erik/obsidian/
  vault` → **syncthing** (fleet folder `/home/erik/backup/Documents/` ↔
  workstation `/home/erik/Documents/`) → workstation **vault.git clone** →
  **`obsidian-sync.nix`** home timer (every 30m: commit-all → fetch → `rebase
  --autostash origin/main` → push) → `git@github.com:ErikBPF/vault.git`.
- So anything written into the discovery vault path flows to GitHub automatically.
  No new clone, no new push timer.

### 4. The curation: hermes is the Karpathy wiki-curator  *(DECISION 2026-06-25)*
**Vault state:** `memories/` populated (168, agentmemory raw); **every curated
layer is EMPTY** — agentmemory `crystals/ lessons/` (its auto-consolidation has
produced nothing in weeks) AND the Karpathy `wiki/` (schema defined in
`AGENTS.md`, never populated). Raw is captured; nothing refines it.

**Architecture (decided):**
- **agentmemory = raw capture + semantic search** (input), via MCP (§1).
- **hermes = the wiki-curator** (output): a glm-5 consolidation cron reads recent
  raw memories (agentmemory MCP recall/smart_search) + sessions → writes/updates
  `wiki/` pages **per `AGENTS.md`** (ingest/query/lint, `[[wikilinks]]`, update
  `index.md`/`log.md`) → syncthing → vault.git. This is the "full move to hermes"
  consolidation, now targeting the **human-readable git wiki**, not agentmemory
  crystals.
- **Vault mounted RW into the hermes container** (decided) so the curator can
  write files. **Scope the mount** to the curator's surface — `wiki/`, `log/`,
  `index.md`, `inbox.md` (+ `raw/` read-only) — NOT the whole vault, to bound the
  YOLO agent's blast radius. The mount target is the discovery vault path that
  syncthing carries.
- **agentmemory auto-consolidation** (`CONSOLIDATION_ENABLED`) can stay on (it's
  inert — produces nothing) or be turned off; hermes owns curation either way.

**Seeding (the "seed if both are needed" step):** `wiki/` is empty. After the
curator + mount are deployed, run a **one-time ingest**: hermes reads the 168
existing `memories/` (+ `raw/`) and writes the initial `wiki/` pages + `index.md`
per `AGENTS.md`. Bound it (batch, glm-5, cap turns). This is a build step, not
done now.

**Security note:** RW vault mount + YOLO agent + auto-push to GitHub = the agent
can push wiki content to vault.git. Mitigated by: scoping the mount to curator
dirs, git-versioned/revertible history, and the workstation rebase loop. Accept
or tighten (e.g. curator writes to a branch) — decide at build.

## What we DON'T build (architecture settled)
- Separate `wiki-curator` *skill* package — the curation is the hermes
  consolidation cron itself (prompt = the `AGENTS.md` ops).
- `on_session_start` wiki-load hook — `AGENTMEMORY_INJECT_CONTEXT=true` already
  injects relevant raw memory; recall is via MCP.
- Discovery vault clone / push timer — the syncthing + `obsidian-sync` loop
  already publishes to vault.git.

## Verification plan (before claiming done)
1. `just dry discovery` green with the new settings.
2. Post-switch: hermes lists the agentmemory MCP tools (`memory_save` etc.);
   MCP handshake OK in logs (no exfil-disable).
3. Round-trip: drive a chat that saves a fact, new session recalls it via
   agentmemory (not built-in memory).
4. agentmemory REST reachable from hermes container
   (`curl -H "Authorization: Bearer …" http://agentmemory:3111/...`).
5. A save produces a markdown file under the vault; the commit timer captures it.
6. Confirm built-in memory injection is gone from the request dump (token drop).

## Rollback
Remove the `mcp_servers.agentmemory` block + re-enable `memory_enabled`;
`just switch-discovery`. Vault git repo is additive (leave or remove). No data
loss — agentmemory state is its own volume.

## 5. Consolidation cron mechanics  *(the curator's runtime — output target = §4)*

The curation in §4 runs as a **hermes native cron job** (full move to hermes,
spicyphus *humans seed / LLM refines*). Output is the Karpathy `wiki/` (§4), NOT
agentmemory crystals — so the earlier "trigger `memory_consolidate` to preserve
the graph" concern is **moot**: agentmemory keeps its own raw graph for recall
(`memory_graph_query`), and the wiki carries its own `[[wikilink]]` graph.

- **Schedule:** nightly (~04:00, after `session_reset`). Native cron (ticker live;
  cron agents get MCP tools via #4219).
- **Model:** `glm-5` (brain judgment). **Cost guard:** once/day, read **deltas
  since last run only** (new `memories/` since the last wiki update), cap
  `max_turns`; drop to `qwen-chat` if the nightly bill bites.
- **Toolset:** agentmemory MCP (recall/smart_search — the INPUT) + file write to
  the scoped vault mount (the OUTPUT). Prompt = the `AGENTS.md` ingest/lint ops.
- **agentmemory auto-consolidation:** leave as-is (inert) or disable
  (`CONSOLIDATION_ENABLED=false`) — irrelevant now that hermes curates the wiki,
  not crystals. Keep `GRAPH_EXTRACTION_ENABLED` for `memory_graph_query` recall.
- **Cron is runtime state** → **seed-on-boot** (bootstrap creates the job if
  absent) to stay declarative, or accept as restic-backed state.

**Build-time verifies:**
- hermes can write `wiki/` through the scoped vault mount and it reaches vault.git
  via syncthing + `obsidian-sync`.
- The glm-5 nightly cost is acceptable on the shared budget (measure one run).

## Decisions (resolved 2026-06-25)
1. **MCP delivery:** `npx -y @agentmemory/mcp` (egress on first run, cached).
2. **Memory:** run BOTH as a trial (A/B); disable built-in later if agentmemory wins.
3. **Git wiki:** integrate `git@github.com:ErikBPF/vault.git` — discovery-side
   clone, agentmemory exports to a scoped subdir, commit/push timer. (Discovery
   push access verified — authenticates as ErikBPF via `github_erikbpf`.)
4. **Consolidation = wiki curation:** FULL move to hermes, model `glm-5` — hermes
   nightly cron is the Karpathy wiki-curator (reads agentmemory raw memories via
   MCP → writes `wiki/` per AGENTS.md → vault.git). Output target = the git wiki,
   NOT agentmemory crystals. See §4/§5.
5. **Curation target:** Karpathy `wiki/` (decided). **Vault mount:** RW, scoped to
   curator dirs (`wiki/ log/ index.md inbox.md`, `raw/` ro). **Seed:** one-time
   ingest of the 168 existing memories → initial `wiki/`.

## Still open (resolve during build)
- **Two-writer strategy** for vault.git: subdir-scoped pull-rebase push from
  discovery (simple, disjoint paths) vs a dedicated `agent-memory` branch Erik
  merges. Lean subdir-scoped if agentmemory's output is truly namespaced.
- **MCP tool-token budget:** measure the agentmemory tool-def cost from a request
  dump after wiring; gate to save/recall/smart_search if heavy.
- **Secret injection:** verify hermes expands `${VAR}` inside `mcp_servers.env`
  (same as `${OPENAI_API_KEY}`); add `AGENTMEMORY_SECRET` to the hermes sops
  `server_env`. If no expansion, find an alternate path.
- **npm egress:** `npx -y` fetches on first container start — confirm the hermes
  container has outbound npm reach (or pre-warm /opt/data npm cache).
```
