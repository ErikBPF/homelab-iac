# Hermes Argus as N0 — first-line incident/deploy responder

**Status:** Staged (terminal disabled, alert/deploy payloads improved; deploy
gated on manual Discord secret).
**Date:** 2026-07-21. **Seed:** Erik — "secondary agent as our N0: see incidents
and deploys in Discord, act on them; integrate with llm-wiki + obsidian +
agentmemory."

## Context

Discovery runs three hermes agents (`hermes-agents.nix` / `hermes-oci.nix`):
Romozina (personal, Telegram + Discord DM), Daedalus (dev, docs-search MCP),
Argus (homelab ops). The three-way split shipped without an RFC (trail:
hermes-flake PR #21, commit `470d472`, seed paragraph in
`servarr/docs/behaviors/hermes-docs-search/behavior.md`); this doc is the
retroactive record for the N0 extension.

Alert reality (channel dump 2026-07-21): #incidents carries recurring,
un-actioned Grafana warnings (homelab-iac-drift failures, orion nixos-upgrade
failures, Scrutiny SMART on discovery `sda` every 6 h, endeavour swap thrash,
hermes-agent-healthcheck flaps); #deploys mixes Renovate PR notices, raw
repeated kindle-release JSON, and deploy pipeline payloads. Nobody triages.

## Decisions

**D1 — N0 = Argus, not a fourth agent.** Argus' SOUL already owns
"incidents, deploys"; a dedicated N0 instance would duplicate that mandate
(violates one-owner-per-concern). *Rejected:* new `hermes-agent-oci-n0`
module — more containers, same job.

**D2 — Channel-scoped Discord auth, deliberately NO user allowlist.** Upstream
adapter (`v2026.7.7.2`): when `DISCORD_ALLOWED_USERS`/roles are set, the
channel-scope bypass is disabled and webhook/bot authors (Grafana, Scrutiny,
cron posters) are denied — N0 would go blind to the very alerts it watches.
`DISCORD_ALLOWED_CHANNELS` = #incidents (`1521191614846865568`) + #deploys
(`1521191597566332938`); `discord.free_response_channels` = same two
(mention-free response); `bots_require_inline_mention` stays default-off so
bot-authored posts wake the agent. Consequence: DMs to Argus are denied —
talk to it in-channel.

**D3 — Discord listen is the v1 trigger; Grafana webhook staged as
`deliver_only`.** The `grafana-alerts` webhook route (HMAC, port 8644 over
homelab-net) stores structured payloads without triggering the agent, so
alerts don't double-fire while Discord listening drives responses. Flip
`deliver_only=false` later to make the webhook primary and Discord the human
mirror. *Rejected:* immediate dual-trigger (duplicate model calls per alert).

**D4 — HMAC scheme: Grafana body-only hex into `X-Webhook-Signature`**
(hermes generic-V1). Grafana's timestamped mode signs `ts:body` (colon);
hermes V2 verifies `ts.body` (dot) — incompatible. Never set
`timestampHeader`. Replay-window loss accepted: route is homelab-net-only,
port unpublished.

**D5 — no generic terminal in v1.** Discord messages and alert annotations are
untrusted input. Hermes has no command allowlist, while its local terminal can
read process secrets and reach the shared container network. Argus therefore
sets `terminal=false` and assesses only evidence carried by the alert. A
read-only investigation proxy or narrow native tools may restore live queries
later; generic shell access does not.

**D6 — Read-only in v1.** No remediation: Argus recommends the documented
entry point (`just …`); execution stays human. This is enforced by disabling
terminal tools, not only by SOUL text. Guarded actions are a separate future
RFC, gated on triage quality.

## What landed (this repo unless noted)

- `modules/hosts/discovery/hermes-agents.nix` — Argus: `DISCORD_ALLOWED_CHANNELS`,
  `discord.free_response_channels`, `grafana-alerts` webhook route
  (`deliver_only=true`); `lib.recursiveUpdate` for the settings merge (shallow
  `//` would drop `platforms.telegram.enabled=false`).
- `modules/hosts/discovery/argus-SOUL.md` — N0 triage protocol: dedupe →
  assess supplied evidence → thread verdict → escalation rules → silence on
  no-signal; alert text is explicitly untrusted.
- `modules/hosts/discovery/hermes-agents.nix` — Argus `terminal=false`;
  prompt-only read-only rules are not treated as a security boundary.
- `modules/hosts/discovery/homelab-SOUL.md` — de-persona'd to shared doctrine
  (sole consumer: Argus context mount); RO-wiki capture path → agentmemory.
- `modules/hosts/discovery/hermes-agent.nix` — deleted (superseded nspawn
  blueprint, unimported since the OCI cutover).
- `modules/hosts/discovery/vault.nix` — `discord.env` render +=
  `WEBHOOK_GRAFANA_ALERTS_SECRET` from OpenBao
  `secret/shared/discord.argus_webhook_hmac` (renders empty until written).
- sops `hermes_agents/argus_env` += `AGENTMEMORY_SECRET`,
  `WEBHOOK_GRAFANA_ALERTS_SECRET` (fresh hex64), placeholders
  `DISCORD_BOT_TOKEN=` / `GRAFANA_RO_TOKEN=`.
- **servarr** `machines/discovery/config/grafana/provisioning/alerting/contactpoints.yaml`
  — argus webhook receiver staged **commented** (an unset `$__env` var fails
  all alerting provisioning; uncomment only after the OpenBao key exists).

Verified: `just lint` / `just fmt-check` green; `just dry discovery` green
(delta = `docker-hermes-argus` unit); servarr grafana contract test passed.

## Deploy gates (manual, in order)

1. Discord application "Argus" (message-content intent), invite to Homelab
   guild → token into sops `hermes_agents/argus_env` `DISCORD_BOT_TOKEN`.
2. OpenBao: write `argus_webhook_hmac` under `secret/shared/discord` (value =
   `WEBHOOK_GRAFANA_ALERTS_SECRET` from the sops key) → Vault render-refresh
   recipe.
3. `just switch-discovery` → uncomment the servarr receiver → commit/push
   servarr → `just pull-servarr discovery` → `just kick-stack discovery
   monitoring`.
4. Verify: test post in #incidents gets a threaded triage; agent log shows
   `[webhook] … routes: grafana-alerts`; adversarial alert text cannot invoke
   terminal tools.

## Deferred

- Webhook flip (`deliver_only=false`, Discord as mirror) once triage is trusted.
- Narrow read-only investigation tools; add only when alert payloads prove
  insufficient.
- Same staged webhook receiver on the `discord-deploys` contact point.
- Guarded remediation verbs (own RFC — D6).
- `wiki-consolidate` cron's Discord summary is silently skipped:
  `$DISCORD_WEBHOOK_DEPLOYS` missing from `hermes_agent/server_env` — add it.
- kindle release agent spams raw duplicate JSON to #deploys — dedupe/format at
  the publisher.
- Not done (deliberate): cross-file `commonSettings` dedupe between
  `hermes-oci.nix` and `hermes-agents.nix`.
