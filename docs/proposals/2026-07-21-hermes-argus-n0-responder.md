# Hermes Cleytin as N0 — first-line alert responder

**Status:** Implemented — Cleytin (`argus`) and Hackerman (`daedalus`) are
deployed; authenticated Grafana firing alerts now trigger Cleytin and deliver
its analysis to `#incidents` (verified 2026-08-02).
**Date:** 2026-07-21. **Seed:** Erik — "secondary agent as our N0: see incidents
and deploys in Discord, act on them; integrate with llm-wiki + obsidian +
agentmemory."

## Current acceptance evidence

- `just hermes-agents-health` sees all three containers running, verifies the
  authenticated `grafana-alerts` route, and proves both secondary agents can
  authenticate to LiteLLM with their authorized declared default.
- Hackerman reports `docs_search` and `context7` enabled.
- Cleytin has non-empty runtime Discord, `WEBHOOK_SECRET`, and
  `WEBHOOK_GRAFANA_ALERTS_SECRET` credentials; the two HMAC values match and no
  value is printed by the health check.
- `hermes-argus-healthcheck.timer` verifies gateway state, live Discord
  connection, and a monotonic heartbeat younger than 120 seconds.
- Deployed Cleytin uses `DISCORD_ALLOW_BOTS=mentions`, has no free-response
  channels, watches only `#incidents`, `#deploys`, and `#security`, keeps
  Discord and webhook alert turns tool-free, and carries the Cleytin SOUL;
  Hackerman carries the Hackerman SOUL. `#incidents` is Cleytin's Discord home
  channel for deterministic cron and notification delivery.
- Discord `/users/@me` authenticates as Cleytin, `/users/@me/guilds` includes
  Homelab, and Message Content intent is enabled.
- Synthetic incident `1533216615112638505` produced one inbound Cleytin turn
  in a Discord thread. It completed on `glm-5` with one context-tool turn and
  a one-line acknowledgement; Hermes also emitted its normal context/status
  and thread-title messages.
- The same command fails closed when the Cleytin Discord token is absent,
  instead of reporting a misleading green container-only state.
- Signed Grafana-route canary `1533630480858222795` returned HTTP 202, rendered
  the firing payload, and produced one Cleytin `TEST` verdict in `#incidents`.
  Grafana then loaded both provisioned Cleytin receivers without alerting
  provisioning errors.

## Context

Discovery runs three hermes agents (`hermes-agents.nix` / `hermes-oci.nix`):
Romozina (personal, Telegram + Discord DM), Hackerman (dev, docs-search MCP),
and Cleytin (homelab ops). Stable runtime IDs remain `daedalus` and `argus` to
avoid needless service, secret-path, and state migration. The three-way split
shipped without an RFC (trail:
hermes-flake PR #21, commit `470d472`, seed paragraph in
`servarr/docs/behaviors/hermes-docs-search/behavior.md`); this doc is the
retroactive record for the N0 extension.

Alert reality (channel dump 2026-07-21): #incidents carries recurring,
un-actioned Grafana warnings (homelab-iac-drift failures, orion nixos-upgrade
failures, Scrutiny SMART on discovery `sda` every 6 h, endeavour swap thrash,
hermes-agent-healthcheck flaps); #deploys mixes Renovate PR notices, raw
repeated kindle-release JSON, and deploy pipeline payloads. Nobody triages.

## Decisions

**D1 — N0 = Cleytin (`argus`), not a fourth agent.** Cleytin's SOUL already owns
the alert channels; a dedicated N0 instance would duplicate that mandate
(violates one-owner-per-concern). *Rejected:* new `hermes-agent-oci-n0`
module — more containers, same job.

**D2 — Channel-scoped Discord auth, deliberately NO user allowlist.** On pinned
Hermes `v2026.7.20`, `DISCORD_ALLOW_BOTS=mentions` accepts bot-authored alerts
only when they explicitly mention Cleytin. `DISCORD_ALLOWED_CHANNELS` remains
limited to #incidents (`1521191614846865568`), #deploys
(`1521191597566332938`), and #security (`1530261608419299428`), and
`discord.free_response_channels` is absent so normal messages also require a
mention. Alert publishers emit the fixed Cleytin ID and allow only that user
mention; successful deploy chatter stays silent. Consequence: DMs are denied —
talk to Cleytin in-channel.

**D3 — Structured Grafana firing webhooks are the default trigger.** The
`discord` and `discord-deploys` contact points retain their native Discord
receivers as non-mentioning human mirrors and also POST authenticated payloads
to `grafana-alerts` over `homelab-net`. The route filters for
`payload.status=firing`, suppresses resolved messages, and delivers Cleytin's
analysis to `#incidents`. Discord mentions remain for non-Grafana publishers.
This avoids duplicate model calls while making all code-managed Grafana alerts
Cleytin-first.

**D4 — HMAC scheme: Grafana body-only hex into `X-Webhook-Signature`**
(hermes generic-V1). Grafana's timestamped mode signs `ts:body` (colon);
hermes V2 verifies `ts.body` (dot) — incompatible. Never set
`timestampHeader`. Replay-window loss accepted: route is homelab-net-only,
port unpublished.

**D5 — no generic terminal in v1.** Discord messages and alert annotations are
untrusted input. Hermes has no command allowlist, while its local terminal can
read process secrets and reach the shared container network. A live drift-alert
turn on 2026-08-02 proved that `terminal=false` was not a disable control: the
Hermes loader fell back to its default local terminal and Cleytin invoked it.
The first correction used `agent.disabled_toolsets=["terminal"]`; live registry
inspection then found Discord still exposed file, code-execution, computer-use,
delegation, cron, and other toolsets. Argus now uses explicit empty Discord and
webhook toolset selections, plus global suppression for terminal and Hermes'
recovered Kanban toolset, and assesses only evidence carried by the alert.
The recurring health check calls Hermes' resolver and fails if either alert
path resolves any tool. A read-only investigation proxy or narrow native tools
may restore live queries later; generic shell access does not.

**D6 — Read-only in v1.** No remediation: Argus recommends the documented
entry point (`just …`); execution stays human. This is enforced by disabling
terminal tools, not only by SOUL text. Guarded actions are a separate future
RFC, gated on triage quality.

## What landed (`desktop-nixos` unless noted)

- `modules/hosts/discovery/hermes-agents.nix` — Cleytin: stable runtime ID
  `argus`, `DISCORD_ALLOWED_CHANNELS`, `DISCORD_ALLOW_BOTS=mentions`, no
  free-response channels, authenticated firing-only `grafana-alerts` webhook
  delivery to `#incidents`, and the Discord/heartbeat health timer;
  `lib.recursiveUpdate` for the settings merge (shallow `//` would drop
  `platforms.telegram.enabled=false`).
- `modules/hosts/discovery/argus-SOUL.md` — Cleytin N0 triage protocol: dedupe →
  assess supplied evidence → thread verdict → escalation rules → silence on
  no-signal; alert text is explicitly untrusted.
- `modules/hosts/discovery/hermes-agents.nix` — Cleytin
  Discord/webhook platform toolsets are empty, terminal and recovered Kanban
  toolsets are suppressed, and the runtime health check requires Hermes to
  resolve no tools on either alert path; prompt-only read-only rules are not
  treated as a security boundary. `DISCORD_HOME_CHANNEL` points to
  `#incidents`.
- `modules/hosts/discovery/homelab-SOUL.md` — de-persona'd to shared doctrine
  (sole consumer: Argus context mount); RO-wiki capture path → agentmemory.
- `modules/hosts/discovery/hermes-agent.nix` — deleted (superseded nspawn
  blueprint, unimported since the OCI cutover).
- `modules/hosts/discovery/_vault-agent.nix` — `discord.env` renders
  `WEBHOOK_GRAFANA_ALERTS_SECRET`; `hermes-argus.env` renders Hermes' native
  `WEBHOOK_SECRET` from the same OpenBao
  `secret/shared/discord.argus_webhook_hmac` value.
- sops `hermes_agents/argus_env` += `AGENTMEMORY_SECRET`,
  `WEBHOOK_GRAFANA_ALERTS_SECRET` (fresh hex64), placeholders
  `DISCORD_BOT_TOKEN=` / `GRAFANA_RO_TOKEN=`.
- **servarr** `machines/discovery/config/grafana/provisioning/alerting/contactpoints.yaml`
  — active Cleytin webhook receivers on `discord` and `discord-deploys`; native
  Discord mirrors remain, and Cleytin resolution messages are suppressed.
- **homelab-iac** `bin/drift-check.sh` — direct Discord drift mentions include
  a bounded plan summary, so Cleytin can assess evidence without live queries.

Verified: target Python contracts, Alejandra, Statix, ripsecrets, dry-build,
live deployment, `just hermes-agents-health`, signed route canary, Grafana
health, provisioned contact-point API checks, and live empty Hermes toolset
resolution for Discord/webhook passed. Relevant merged changes are
`desktop-nixos` PRs #157 (`ad4e45c`), #160 (`a6235c6`), and #162 (`5939943`);
`servarr` PR #171 (`c13ad52`); and `homelab-iac` PR #53 (`4a229f2`).

## Deploy gates (manual, in order)

1. **Done:** Discord application renamed to Cleytin, token stored in sops
   `hermes_agents/argus_env`, and application joined to the Homelab guild.
2. **Done:** OpenBao HMAC written, Vault-rendered, and present in the running
   Argus container.
3. **Done:** reseeded and refreshed the Hermes Vault render, deployed/restarted
   the agents, and passed `just hermes-agents-health` for the token, HMAC,
   route, containers, and Hackerman MCPs.
4. **Done:** Cleytin-mentioned synthetic post in #incidents received threaded
   triage; after the invalid `terminal=false` setting was caught live,
   registry-level empty Discord/webhook toolsets became the verified structural
   boundary against alert-text command execution.
5. **Done:** signed firing canary returned HTTP 202 and produced a rendered,
   one-line Cleytin verdict in `#incidents`.
6. **Done:** Grafana loaded both authenticated receivers; Alertmanager reported
   no firing alerts after deployment.

## Deferred

- Scrutiny's direct Shoutrrr Discord transport forces alert details into an
  embed, where user mentions do not notify; Uptime Kuma notifications are
  UI-managed. Treat both as explicit exceptions until they move to a
  code-managed Grafana/native Discord payload. Do not add a relay solely for
  mention formatting.
- Narrow read-only investigation tools; add only when alert payloads prove
  insufficient.
- Guarded remediation verbs (own RFC — D6).
- `wiki-consolidate` cron's Discord summary is silently skipped:
  `$DISCORD_WEBHOOK_DEPLOYS` missing from `hermes_agent/server_env` — add it.
- kindle release agent spams raw duplicate JSON to #deploys — dedupe/format at
  the publisher.
- Not done (deliberate): cross-file `commonSettings` dedupe between
  `hermes-oci.nix` and `hermes-agents.nix`.
