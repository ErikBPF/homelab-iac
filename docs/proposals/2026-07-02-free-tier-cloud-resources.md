# Free-tier cloud resources — usage plan for reliability & privacy

**Status:** Partially implemented — CT monitoring, B2 backups, Modal proof, and
Trivy pilots completed 2026-07-24; remaining forks stay `TODO(erik)`
**Date:** 2026-07-02
**Owner:** erik
**Scope:** Map every verified free-tier cloud resource onto fleet needs, biased
toward **reliability** (more failure domains for the things that already exist)
and **privacy** (nothing readable leaves the house). Quotas were rechecked
against official docs 2026-07-23; lowest-confidence items are flagged inline.

## Executive recommendation

Do not implement this document as one program. Treat free resources as
independent, disposable improvements and ship them in value order:

1. **Acquire telstar:** keep Discovery as the single acquisition owner. Its
   declarative service runs real launch attempts against the IaC-owned
   Terragrunt unit. Capacity reports are useful telemetry, but do not reserve a
   free-tier slot.
2. **Add offsite failure detection:** Grafana Cloud receives only an allowlist
   of non-content metrics and runs outside-in probes. Skip OCI APM initially.
3. **Add backup diversity:** OCI Object Storage adds a service-diverse leg;
   B2 or R2 adds the more valuable provider/account-diverse leg.
4. **Use Cloudflare edge services per public project:** no speculative shared
   platform before a project needs it.
5. **Defer third-party AI and database services:** weak fleet benefit and the
   largest privacy/abandonment risk.

No free-tier resource becomes sole storage, sole monitoring, identity, DNS, or
recovery path. Every phase must remain removable without breaking the fleet.

## 0. Principles

1. **Free tiers are revocable — never in the critical path.** Everything here
   is a *redundant leg* or an *edge convenience*. The fleet must keep working
   if any provider yanks its free tier tomorrow (Oracle halved A1 in June 2026
   with zero notice; Scaleway/Storj/Railway/Fly free tiers are all dead).
2. **Privacy: ciphertext-only off-prem.** Backups leave the house only
   restic/age-encrypted (provider sees ciphertext + object sizes/timing).
   Metrics mirrors carry *operational* metadata only (series names, values) —
   acceptable; logs mirrors are NOT in scope (log lines leak content).
   Personal/hermes prompt content never routes through third-party
   inference or logging layers; only already-external model traffic may.
3. **One new account max per phase.** Each provider account is attack surface
   (credentials, recovery email, billing). Prefer stacking on accounts we
   already hold (Oracle, Cloudflare, GitHub) before adding new ones.
4. **Blast-domain awareness.** OCI Object Storage/Vault live in the *same
   Oracle account* as voyager — they diversify *service/failure* domains, not
   the account domain. True provider diversity needs a second company (B2/R2).
5. **Prefer hard stops over billing alerts.** A budget notification is not a
   spending cap. Prefer providers whose free plan rejects over-quota work
   (Cloudflare, GitHub Models) or supports an explicit spend cap. Any PAYG
   account needs service quotas and the smallest possible blast radius before
   workloads land.

## 0a. Category inventory

This is the evaluated catalog, not an implementation checklist. `Use` means a
real fleet fit exists; `hold` means wait for a concrete project; `skip` means
the free offer does not justify another account.

### General compute and application hosting

| Service | Perpetual free allocation | Fit | Decision |
|---|---|---|---|
| OCI A1 | 2 OCPU / 12 GB in the tenancy home region | telstar public-project host | **use**, acquisition blocked on capacity |
| GCP Compute Engine | one US `e2-micro`, 30 GB disk, 1 GB egress/mo | international probe/relay; IPv6 + Tailscale/CF Tunnel avoids paid IPv4 | **hold** until shell-level foreign node is needed |
| GCP Cloud Run | 2M requests, 180k vCPU-s, 360k GiB-s/mo | stateless public APIs and jobs | **hold** per project |
| Azure Container Apps | 2M requests, 180k vCPU-s, 360k GiB-s/mo | strongest non-VM container alternative | **hold** per project |
| Azure Functions | 1M requests/mo | webhooks and scheduled glue | **hold**; CF Workers already cover this |
| Azure Static Web Apps | 100 GB bandwidth/subscription, 2 custom domains, 0.5 GB/app | static public projects | **skip** while CF Pages suffices |
| AWS Lambda | 1M requests + 400k GB-s/mo | AWS-specific event glue | **skip** without AWS-specific need |
| Koyeb | one 0.1 vCPU / 512 MB / 2 GB web instance; sleeps after 1 h idle, no volume | demo or webhook only | **skip** as fleet node |
| DigitalOcean | 90k GiB-s Functions; three static apps | functions/static only; no free Droplet | **skip** |
| Heroku | no free dyno or database | none | **reject** |

GCP is the only credible free international **machine** alternative. AWS and
Azure VMs expire after 6/12 months respectively; they are trials, not fleet
capacity. GCP requires a billing account and bills overages, so an international
satellite must be IPv6-only, stateless, remotely built, and disposable.

### Storage and backup

| Service | Perpetual free allocation | Fit | Decision |
|---|---|---|---|
| OCI Object Storage | 20 GB, S3-compatible, retention rules | WORM crown-jewel leg | **use** |
| Backblaze B2 | 10 GB; 1 GB download/day; no card to start | provider/account-diverse restic leg | **preferred** over R2 |
| Cloudflare R2 | 10 GB; 1M Class A + 10M Class B ops/mo; free egress | backup or public assets | **alternative** to B2 |
| GCP Cloud Storage | 5 GB in selected US regions; 100 GB egress/mo | satellite-local objects | **hold** with GCP node |
| Supabase Storage | 1 GB, 5 GB direct + 5 GB cached egress | public-app uploads | **hold** per app |
| AWS S3 / Azure Blob / DigitalOcean Spaces | no useful perpetual generic allocation | — | **skip** |

Never stripe a backup across free providers. Each leg must be independently
restorable; otherwise several revocable services become one fragile backup.

### Relational, document, and edge databases

| Service | Perpetual free allocation | Fit | Decision |
|---|---|---|---|
| Azure SQL Database | up to 10 serverless DBs, 100k vCore-s + 32 GB each | largest free relational offer; public projects only | **hold**; validate billing controls first |
| CockroachDB Basic | 10 GiB + 50M RUs/mo | durable SQL app state | **preferred** hosted SQL when Postgres compatibility is not required |
| Neon | 0.5 GB/project + 100 CU-h/project/mo; scales to zero | real PostgreSQL for intermittent apps | **hold** |
| Cloudflare D1 | 5 GB; 5M rows read + 100k written/day | edge-native SQLite state | **preferred** for CF-native apps |
| Turso | 5 GB, 500M reads/mo | distributed/read-heavy SQLite | **hold** |
| AWS DynamoDB | 25 GB + 25 RCU/WCU | serverless control/event state | **skip** without AWS-specific need |
| Azure Cosmos DB | 25 GB + 1k RU/s | managed NoSQL | **hold** |
| Azure DocumentDB | dedicated MongoDB-compatible cluster, 32 GB | unusually generous; young offer | **hold**, re-verify before use |
| Supabase | 500 MB PostgreSQL + auth/realtime/storage; pauses after 1 idle week | complete public-app backend | **hold** |
| MongoDB Atlas M0 | 512 MB, shared | Mongo-specific prototypes | **skip** unless API compatibility is required |
| Koyeb PostgreSQL | 5 compute hours/mo | demo only | **reject** |
| PlanetScale | no free plan | managed MySQL | **skip** |

No hosted database stores fleet state, secrets, hermes memory, or HA data.

### Vector databases and embedding backends

| Service | Perpetual free allocation | Fit | Decision |
|---|---|---|---|
| Local Qdrant/llama.cpp | bounded by Kepler storage/compute | private hermes/wiki vectors | **default** |
| Cloudflare Vectorize | 5M stored + 30M queried dimensions/mo | pairs with Workers AI | **hold** behind privacy fork |
| Zilliz | 5 GB, 2.5M vCUs/mo, up to 5 collections | about 1M 768-d vectors | best large hosted free tier |
| Qdrant Cloud | 0.5 vCPU, 1 GB RAM, 4 GB disk | familiar API; about 1M 768-d vectors | **reject** for durable use: deleted after 4 idle weeks |
| Pinecone Starter | 2 GB, 2M writes + 1M reads/mo; 5 indexes | public-project semantic search | **hold** |
| Upstash Vector | 10k queries + 10k updates/day, max 1536 dimensions | low-volume serverless search | **hold** |
| Neon/Supabase pgvector | shares DB quota | avoid a separate vector account for small datasets | **prefer** when app DB already exists |

Vectors can leak source meaning and are not anonymized data. Personal embeddings
remain local even when raw text is not stored off-prem.

### Connectivity and edge

| Service | Perpetual free allocation | Fit | Decision |
|---|---|---|---|
| Tailscale Personal | 6 users, unlimited user devices, 50 tagged resources | fleet management plane | **keep** |
| Cloudflare Tunnel/DNS/CDN | free outbound tunnel and edge | public ingress without public origin IPs | **keep** |
| Cloudflare Workers/Pages | 100k Worker requests/day; 500 Pages builds/mo | edge glue/static sites | **use per project** |
| Cloudflare Queues | 10k ops/day, 24 h retention | small asynchronous ingestion | **hold** |
| Cloudflare Turnstile | unlimited verification within widget limits | public forms | **use per project** |
| ngrok | one dev domain, 20k HTTP requests and 1 GB transfer; free credit is one-time | development tunnels | **reject** for production |

### Monitoring and incident detection

| Service | Perpetual free allocation | Fit | Decision |
|---|---|---|---|
| Grafana Cloud | 10k series, 100k API + 10k browser synthetics, 3 users | filtered metrics mirror + outside-in probes | **preferred** |
| UptimeRobot | 50 monitors, 5-minute checks, basic status pages | broad outside-in coverage, no card | best simple alternative |
| Better Stack | 10 monitors/heartbeats, 1 status page; 3 GB logs/traces | stronger alert workflow, smaller monitor count | alternative if status/on-call UX wins |
| Healthchecks.io | 20 jobs, 100 log entries/job | backup/cron dead-man checks | **skip** if Grafana alerts cover them |
| Honeycomb | 20M events + 100M metric points/mo, 2 triggers | application traces | **hold** for a public distributed app |
| OCI APM | 10 synthetic runs/hour | same-account external vantage | **skip** if Grafana selected |

One monitoring account is enough initially. Grafana wins because it fixes both
inside-out metrics and outside-in detection; UptimeRobot wins only if simplicity
matters more than the Prometheus mirror.

### Security and supply-chain tooling

| Service | Perpetual free allocation | Fit | Decision |
|---|---|---|---|
| Cloudflare CT Monitoring | all zones; account-member email alerts | rogue certificate detection | **enable now** |
| Cloudflare WAF/Turnstile | 5 custom WAF rules + 1 rate rule; form protection | public edge | **use per project** |
| Fleet Renovate | dependency and digest PRs across six repos | dependency maintenance | **keep** |
| GitHub Dependabot | alerts/updates on hosted repos | duplicates fleet Renovate | **skip** |
| GitHub CodeQL/code scanning | free for public repos; private repos require GitHub Code Security | public OSS repos | **enable on public projects** |
| Trivy OSS | local/CI image, filesystem, secret, dependency, and IaC scanning | Compose images + IaC without hosted source upload | **preferred fleet scanner**, pinned and isolated |
| Semgrep Free | 10 private repos/contributors; Code + Supply Chain | deeper SAST if Trivy leaves a demonstrated gap | **secondary** |
| Snyk Free | 5 projects; monthly SCA/SAST/IaC/container test caps | broad scanner, lower project limit | **skip** unless Semgrep misses a needed ecosystem |
| GCP Security Command Center Standard | baseline GCP posture/vulnerability checks | GCP satellite only | **enable if GCP account exists** |
| AWS CloudTrail/IAM/Organizations | free control-plane capabilities; log storage can bill | AWS account hygiene | **enable only if AWS exists** |

Do not create AWS/GCP accounts solely for their account-local security tools.
For private repos, prefer scanners running in existing CI; source upload and
another security dashboard need explicit value.

### GPU, inference, CI, and batch compute

| Service | Perpetual free allocation | Fit | Decision |
|---|---|---|---|
| Orion RX 9070 XT | owned 16 GB VRAM | private fp16 LoRA/inference | **default** |
| Kaggle | about 30 P100 GPU h/week; quota varies | non-sensitive notebook training | **use after privacy decision** |
| Lightning AI | 15 credits/mo, advertised up to ~80 T4 h; 4 h Studio restarts | SSH workspace and checkpointed training | **best new training alternative** |
| Modal | $30 compute credit/mo; T4 through B300 | scripted batch training/evaluation/inference | **best automation candidate** |
| Colab | free GPU/TPU, no guaranteed type/quota | manual overflow | fallback only |
| Hugging Face ZeroGPU | 5 min/day for free users; own hosting requires PRO | short interactive inference | **skip** for training/runtime |
| Cloudflare Workers AI | 10k neurons/day, hard stop | public embeddings/STT/images/small LLMs | **use behind privacy boundary** |
| Groq | model-specific daily LLM/Whisper quotas | fast external inference | **use for non-personal traffic** |
| GitHub Models | free rate-limited model catalog; paid use opt-in | CI eval/smoke tests | **hold** |
| GitHub Actions | public repos unlimited; private quota plan-dependent | public builds/tests and scheduled checks | **keep** |

GCP, AWS, Azure, and OCI have no perpetual raw GPU VM allocation. Their free AI
APIs are inference products, not training capacity.

## 1. Oracle (existing account)

### 1a. Object Storage — 20 GB, S3-compat, WORM-capable

- **Usage:** third crown-jewel leg. Bucket `crown-jewels` (home region
  `sa-saopaulo-1`), versioning + **retention rule** (time-bound WORM — even a
  compromised console session can't delete inside the window; strictly
  stronger than voyager's append-only REST).
- **Wiring:** two new restic jobs on discovery mirroring the `-rest` pair
  (`restic-backups-vault-oci`, `restic-backups-tofu-state-oci`) →
  `s3:<namespace>.compat.objectstorage.sa-saopaulo-1.oraclecloud.com/crown-jewels`.
  Customer Secret Keys (max 2/user) in **sops, not OpenBao** — backup paths
  must survive a sealed vault (proven 2026-07-01). Dead-man textfile metric →
  existing Grafana routing.
- **Privacy:** restic client-side encryption; Oracle sees ciphertext.
- **Reliability:** survives voyager loss + house loss; NOT account loss.
- Gotchas: S3 API = SigV4, path-style; buckets created via S3 API land in the
  root compartment unless the user's designated compartment is set.

### 1b. OCI Vault — 150 secrets free

- **Usage:** third custody domain for the escrow blobs (`age-key.age` 257 B,
  `sops-config.tar.gz`) as base64 secrets. Accessed with Oracle account creds
  only — independent of fleet and house.
- **Never store:** `vault_unseal_key` — would co-locate with the OCI-stored
  OpenBao snapshots (1a), breaking the runbook's separation rule.
- **Privacy:** blobs are already passphrase-age-encrypted; Oracle holds
  double-wrapped ciphertext.

### 1c. APM synthetic monitoring — 10 runs/hr free

- **Usage:** external probe of 1–2 public vhosts from Oracle's vantage →
  OCI Alarm → Notifications (email 1k/mo, or HTTPS → CF Worker reshaping to
  Discord). Partial fix for the "Prometheus on discovery can't report
  discovery's death" SPOF.
- **Note:** likely *superseded by Grafana Cloud synthetics* (§3) which are
  free at 100k API checks/mo with saner alert routing. `TODO(erik)`: pick one
  (running both costs nothing but doubles config surface).

### 1d. Second E2.1.Micro (1 free x86 VM unused)

- **Usage candidates**, ranked:
  1. **Off-prem uptime-kuma + public status page** — complements synthetics
     (history/dashboard vs raw probes), watches all public endpoints.
  2. Restic REST mirror of voyager (weak — same account/region).
  3. Unprovisioned headroom (block budget: voyager ~48 + telstar 47 + micro
     47 ≈ 142 of 200 GB — fits).
- `TODO(erik)`: role. Recommendation: (1).

### 1e. A1 acquisition plan (telstar unblock)

Use the existing declarative systemd service on Discovery, not cron and not a
second host. Credentials, logs, restart policy, and failure state already
belong there. The service drives the existing Terragrunt unit; Terragrunt state
remains the creation lock and source of truth.

Current schedule:

- One Discovery service makes a real create attempt every 60 seconds for up to
  seven days.
- systemd restarts genuine service failures with a bounded start limit.
- No second poller may run concurrently; Terragrunt's remote state lock remains
  defense in depth, not normal coordination.
- On success the script emits `public_ip` and exits zero, ending the loop.
  Human cutover remains deliberate: update fleet metadata, regenerate
  `fleet.json`, then run the documented Telstar deploy recipe.

Why not capacity-report gating: OCI documents capacity reports as a point-in-time
guide for instance creation. They do not reserve capacity or prove an Always
Free launch will succeed. Record a report as optional telemetry immediately
as separate telemetry, but let the real, idempotent apply decide.

Rollout gates:

1. Keep the IaC-owned retry script as the only launch implementation.
2. Keep the declarative Discovery service as the only scheduler.
3. Dry-build Discovery before changes and deploy through its documented recipe.
4. Confirm capacity exhaustion is normal, real errors fail, and no paid shape
   is planned.

**Cost guard:** keep the account Free Tier and pin shape, OCPU, memory, boot
volume, region, and `create_instance=true` in reviewed IaC. Before enabling the
service, `terragrunt plan` must contain exactly one Always-Free-eligible A1
instance and no paid resource. Do not auto-provision after any PAYG upgrade
until compartment quotas and budget alarms are separately reviewed.

- **Parallel lever — PAYG upgrade** (`TODO(erik)`, the big fork): paid-pool
  capacity priority (the only *reliable* A1 fix), idle-reclamation immunity,
  Object Storage 20→30 GB (per-tier), unlocks the AI-service monthly quotas
  (5 h Speech, 5k tx Vision/Language/DocU). $0 while under limits; risk =
  a real card on an account that can now bill.

### 1f. Rejected on OCI

- Autonomous DB 26ai (vector search real but 1 OCPU + un-tunable vector
  memory — Vectorize/Zilliz beat it), MySQL HeatWave free (vector store
  excluded from free — trap), GenAI service (no free quota), Data Science /
  GPU (none, ever).

## 2. Cloudflare (existing account)

### 2a. Turn on today (zero cost, zero decisions)

- **CT Monitoring** — email alert on any cert issued for our domains. Free
  rogue-issuance detection. Pure win.
- **Turnstile** — 20 widgets, unlimited siteverify. CAPTCHA for any public
  form (telstar projects). Privacy: visitor-side CF JS (already true for
  proxied zones).
- **WAF free**: 5 custom rules + 1 rate-limit rule (10 s window) — geo/path
  blocks in front of the tunnel. Bot Fight Mode **stays off** on API zones
  (all-or-nothing, breaks API clients).

### 2b. AI Gateway (free: caching, rate-limit, analytics)

- **Usage:** front LiteLLM's *external free upstreams only* (Groq, Cerebras,
  Gemini, OpenRouter): response caching, per-provider rate-limit smoothing,
  unified usage analytics.
- **Privacy boundary:** prompts to these providers already leave the house;
  the gateway adds CF as a reader **only if logging is enabled** — and the
  100k persisted-log cap is **total, not monthly**. Policy: logging off (or
  debug-window only); local model traffic (kepler/orion) and hermes personal
  routes **never** pass through it. Langfuse stays the system of record.

### 2c. Telstar edge (rides telstar's timeline)

- **Pages / Workers static assets** — static frontends, free unlimited
  bandwidth, off the reclaimable VM entirely.
- **Workers** (100k req/day, 10 ms CPU) — glue APIs, the Discord-reshaper.
- **Durable Objects** (free since 2025, SQLite, 5 GB) + **Queues** (free
  since 2026-02, 10k ops/day) — small stateful coordination without touching
  home infra.
- **Hyperdrive** (100k queries/day) — only if a Worker must reach a Postgres
  over the tunnel; prefer Nile/Cockroach (§4) so nothing points home.
- Universal SSL covers one subdomain level — keep public hostnames flat.

### 2d. R2 — 10 GB, zero egress (⚠️ card required to activate)

- **Usage:** fourth crown-jewel leg — the **provider-diverse** one (answers
  the Oracle-account blast domain). Same restic `s3:` pattern as 1a. Also
  free static-asset origin for large public files (zero egress).
- `TODO(erik)`: **R2 vs Backblaze B2** (10 GB, no card, free egress to CF,
  native restic `b2:`) as the diverse leg. B2 avoids putting a card on the
  CF account; R2 keeps everything in two accounts. Either satisfies the
  requirement — pick one, don't run both.

### 2e. Workers AI + Vectorize (hermes P6 enabler)

- **Usage:** bge-m3 embeddings (~9.3M tok/day) + Vectorize (30M queried +
  5M stored dims/mo) = complete free semantic-search backend for the hermes
  wiki/P6 "unified approach".
- **Privacy:** wiki content would be embedded **off-prem** — hermes memory is
  personal data. `TODO(erik)`: acceptable, or keep embeddings local (kepler
  runs embedding models already — bge-m3 via llama.cpp is cheap) and use
  Vectorize only for *storage* of vectors (vectors leak less than text, but
  are invertible in principle)? Conservative default: **embed and store
  locally; revisit only if kepler capacity hurts.**
- **Rejected:** Browser Rendering for kindle-dash (10 min/day ≈ 30–60
  screenshots — too thin; self-hosted pipeline stays).

## 3. Grafana Cloud free — the offsite monitoring mirror

- **Quota:** 10k active series, 50 GB logs, 14-day retention, alerting + IRM,
  100k synthetic API checks/mo, 3 users. Native Prometheus `remote_write` +
  Loki push. No card.
- **Usage (the SPOF fix):** discovery Prometheus `remote_write` of a
  **filtered ~20-series allowlist** (host `up`, backup dead-man gauges,
  `oci_a1_capacity_available`, OpenBao seal probe) → Grafana Cloud alert
  rules fire even when discovery is dead. Synthetics probe the public vhosts
  (replaces 1c). IRM → Discord/email.
- **Privacy:** metric names + numeric values only — operational metadata, no
  content. **Do not** mirror logs (lines leak content) — the 50 GB logs quota
  stays unused by policy.
- **Reliability caveat:** over-quota behavior unstated on the pricing page
  (historically caps, never bills — MEDIUM confidence). The allowlist keeps
  us 3 orders of magnitude under quota.
- **Complement:** Better Stack free (10 uptime monitors + heartbeats + 1
  status page) as an orthogonal outside-in probe — `TODO(erik)`: worth the
   extra account? (Principle 3 says at most one new account per phase; Grafana
   Cloud is the higher-value one.)
- **Simpler alternative:** UptimeRobot has 50 monitors at 5-minute intervals
  with basic status pages and no card. Choose it *instead of* Grafana when only
  outside-in checks matter; it does not solve the filtered-metrics mirror.
- **Dead-man specialist:** Healthchecks.io monitors 20 jobs free. It adds no
  value once Grafana receives backup completion gauges and alerts on them.
- **Application tracing:** Honeycomb's 20M events + 100M metric points/mo is
  attractive for a future distributed public app, not for fleet telemetry.
- **Avoid:** New Relic as DR sink (over-quota = total platform lockout —
  exactly the failure mode being defended against).

## 4. Free databases (telstar-adjacent; no fleet dependencies)

| Service | Free | Fit | Privacy note |
|---|---|---|---|
| **Azure SQL Database** | up to 10 × 32 GB, 100k vCore-s/mo each | largest allowance; serverless public apps | public-project data only |
| **CockroachDB Basic** | 10 GiB + 50M RUs/mo | same, bigger | same |
| **Neon** (Postgres) | 0.5 GB + 100 CU-h/project/mo | intermittent Postgres apps | same |
| **Turso** (SQLite) | 5 GB, 500M reads/mo | read-heavy public apps | same |
| **Cloudflare D1** (SQLite) | 5 GB, daily row quotas | CF-native public apps | same |
| **Zilliz** (vector) | 5 GB ≈ 1M 768-d vectors | public semantic search | vectors invertible in principle |
| **Pinecone Starter** (vector) | 2 GB, monthly read/write quotas | smaller public semantic search | same |
| Avoid: Qdrant free | 1 GB RAM / 4 GB disk | prototypes only | **deleted after 4 weeks idle** |
| Avoid: ClickHouse Cloud | trial-only | Langfuse stays self-hosted | — |

The full database/vector comparison and decisions live in §0a. Traps recorded:
AWS free-plan accounts auto-close at 6 months even though DynamoDB has an
always-free quota; CloudAMQP deletes idle queues at 28 d; Upstash Kafka, Xata
free, and PlanetScale free are dead. Recheck Azure SQL's over-quota behavior
before first use; a generous quota is not a spending cap.

## 5. Free inference / GPU (privacy-tiered)

**Tier P0 — personal/hermes/HA-voice content: local only.** kepler/orion
llama.cpp, whisper, piper. No change.

**Tier P1 — already-external, non-personal traffic** (LiteLLM routes that
today hit free API models): add overflow entries —
- Groq: llama-3.3-70b (100k tok/day), **whisper-large-v3 (2k req/day)** as a
  *public/non-personal* STT fallback only (HA voice audio is personal → stays
  local; `TODO(erik)` if a degraded-mode exception is acceptable when kepler
  is down).
- Cerebras gpt-oss-120b (1M tok/day, 5 RPM).
- Gemini Flash — ⚠️ **free tier trains on data**: restrict to fully public
  content or skip. `TODO(erik)`.
- OpenRouter one-time $10 → 1,000 free req/day across the :free pool —
  cheapest breadth unlock. `TODO(erik)` (small real spend).

**Training:** local Orion remains the private default. External, non-sensitive
options:

- Kaggle documents a P100 and about 30 GPU h/week; actual accelerator and quota
  vary. Do not plan around the previous T4×2 assumption.
- Lightning AI grants 15 monthly credits (advertised as up to ~80 T4 h), a
  50 GB persistent workspace, and SSH; free Studios restart every 4 h, so
  checkpoint/resume is mandatory.
- Modal grants $30 monthly compute credit across T4/L4/A10/A100/H100/H200/B200/
  B300 and is the best fit for scripted batch jobs. Add hard spend controls
  before attaching billing.
- Colab provides opportunistic GPU/TPU access with no guaranteed type or quota;
  keep it manual-only.
- Hugging Face ZeroGPU gives a free user 5 min/day on shared 48/96 GB RTX Pro
  6000 hardware, but hosting a Space requires PRO. Useful for short tests, not
  training or runtime.

Own voice recordings remain `TODO(erik)` for any external trainer.

**Managed inference:** Workers AI provides 10k neurons/day with a hard stop
(bge-m3 ≈ 9.3M input tok/day; Whisper large-v3-turbo ≈ 214 audio min/day).
GitHub Models adds free rate-limited model evaluation with paid usage disabled
by default. Neither changes the P0 local-only boundary.

## 6. Opportunistic / apply-and-forget

- **Vultr Free Tier Program** (1 vCPU/512 MB, application + lottery): apply,
  architect nothing around it. If granted → candidate external probe host or
  tiny public relay.
- **Koyeb free web instance** — 512 MB, no persistent volume, mandatory
  scale-to-zero after 1 h idle. Demo/webhook fallback only, not a probe host.
- **DigitalOcean Functions** — 90k GiB-s/mo, plus three free static App
  Platform sites. Cloudflare already covers both with fewer accounts.
- **GitHub Actions (public repos, unlimited)** — already-free cron compute;
  candidate runner for the weekly `restic check` against OCI/R2 legs (creds
  via GH secrets — `TODO(erik)`: acceptable? Conservative: keep checks on
  discovery).
- **Semgrep Free** — Code + Supply Chain for up to 10 private repos and
  contributors. Best security trial because it can scan in existing CI without
  persisting source in another build service; compare against current local
  linters before adding it.
- **Trivy OSS** — better first fit than a hosted scanner: scan Compose images
  and `homelab-iac` configuration in existing CI, with no account or source
  upload. Harbor's embedded adapter stays off; scheduled CI avoids its
  persistent RAM cost. The Trivy Actions ecosystem suffered a supply-chain
  compromise in March 2026: use a verified immutable release/SHA, never
  `master`, `latest`, or a mutable pre-remediation tag, and give scan jobs no
  deployment secrets.

## 6a. Selected implementation plans

These match the adopted stack-review sequence: **1 CT monitoring, 2 B2,
4 Modal, 5 scanning**. Planning does not authorize account creation, billing,
secret changes, or deployment.

### Plan 1 — Cloudflare CT monitoring

**Execution:** enabled by the account owner 2026-07-24. Independent API
verification is unavailable with the fleet's scoped token (`403`; it lacks
`SSL and Certificates Read`), so the dashboard remains authoritative.

- Enable CT monitoring for the existing `pastelariadev.com` zone.
- Route alerts to the existing operator email; no Worker or webhook.
- If the provider cannot manage it, record the dashboard-only setting in
  `homelab-iac`.
- Verify the zone subscription; do not manufacture a certificate incident.

### Plan 2 — B2 crown-jewel backup leg

**Execution:** implemented and deployed 2026-07-24. Discovery now writes
OpenBao and OpenTofu-state Restic repositories through B2's S3-compatible
endpoint. The bucket-scoped key is sops-encrypted; the plaintext handoff was
deleted after migration. Both jobs retain 7 daily, 4 weekly, and 3 monthly
snapshots and export distinct node-exporter liveness metrics.

Verification passed for both repositories: full `restic check --read-data`,
then a streamed `restic dump latest | cmp` against the live OpenBao snapshot
and one OpenTofu-state file. `just verify-b2-backups` is the repeatable,
value-safe operator entry point.

Independent Grafana dead-man rules for both B2 metrics were added locally in
`servarr` on 2026-07-24; deployment waits for that repository's overlapping
in-progress alert-template/test changes to land through its git-only flow.

- Create one private B2 bucket and one application key scoped to it.
- Put credentials in the existing sops/bootstrap-secret path, never git or
  GitHub Actions.
- Reuse current restic jobs. Add only a repository target for OpenBao
  snapshots, OpenTofu state, encrypted bootstrap escrow, and optionally k3s
  etcd snapshots. Exclude media, photos, logs, AgentMemory, and models.
- Cap retention below 10 GB; export age and size through the existing
  Prometheus textfile path.
- Gate completion on `restic check` plus restoring one OpenBao snapshot and
  one tofu-state object into a temporary local directory.

### Plan 4 — Modal batch-evaluation proof

**Execution:** proof completed 2026-07-24. A synthetic-only three-case exact
tool-call scorer ran successfully as an ephemeral Modal App: 0.125 CPU,
128 MiB, one container maximum, 60-second timeout, five-second scale-down,
no GPU, secret, persistent volume, deployment, repo source, or home data.
The returned `2/3` exact score matched the local assertion.

Do not upload the current `ha_agent` package for future proofs: its scorer
imports the real grounding snapshot/entity catalog. A production Modal eval
requires a deliberately sanitized export boundary first.

- Reuse `ha-agent`'s evaluation entry point; do not build a generic GPU layer.
- Export one synthetic-only shard with no real `entity_id`, voice, secret,
  hostname, or home-state data.
- Run one bounded Modal batch with explicit timeout/concurrency and no
  persistent volume. Training and personal inference remain on Orion.
- Keep aggregate metrics and reproducible configuration; discard remote
  inputs/outputs.
- Continue only if wall-clock or cost improves over Orion.

### Plan 5 — Trivy-first repository scanning

**Execution:** implemented locally 2026-07-24 in `homelab-iac` and
`kindle-dash`, report-only. Both use the immutable `v0.36.0` action commit.
Local Trivy 0.72.0 baselines found zero high/critical IaC or image findings.

- Pilot `homelab-iac` with Trivy filesystem/config scanning.
- Pilot `kindle-dash` image scanning by reusing its existing build, SBOM,
  provenance, and signing workflow; scan the exact produced digest.
- Pin the action/setup path to verified immutable SHAs/releases newer than the
  March 2026 remediation. Grant `contents: read` only.
- Start report-only. After triage, fail PRs only on fixable `CRITICAL`
  findings. Every ignore needs an ID, reason, and expiry.
- Keep Harbor's resident Trivy adapter off. Add Semgrep only if the pilot
  demonstrates a source-analysis gap.

## 7. Phasing

| Phase | Items | Decisions needed |
|---|---|---|
| **0 — now** | Discovery Telstar capture service; CT monitoring on; OCI Vault escrow copy; Vultr application | none |
| **1 — DR legs** | OCI bucket (WORM) + 2 restic jobs + dead-man metrics; diverse leg R2-or-B2 | 2d fork |
| **2 — monitoring mirror** | Grafana Cloud account, filtered remote_write allowlist, cloud alert rules, synthetics; retire/skip OCI APM | 1c/§3 forks |
| **3 — telstar edge** | Pages/Workers/Turnstile/DB per project; blocked on A1 capacity (or PAYG) | 1e PAYG fork |
| **4 — AI routing/training** | AI Gateway + overflow routes; Kaggle or Lightning wake-word run; Modal batch-eval proof | §5 privacy/billing forks |

Each phase lands as its own PR with verify gates (restore a file from each new
restic leg; force-fire each new alert; kill -9 test against the probe timer).

## 8. Decision forks

1. ~~**R2 vs B2**~~ — **B2 selected and deployed 2026-07-24.**
2. **PAYG upgrade** on Oracle (reliable A1 + reclamation immunity vs card).
3. Second micro role (uptime-kuma vs headroom).
4. OCI APM vs Grafana Cloud synthetics (or both).
5. Better Stack second account: yes/no.
6. hermes embeddings: local-only (default) vs Workers AI off-prem.
7. Gemini free (trains on data): exclude entirely?
8. Groq whisper as degraded-mode voice STT: allowed?
9. OpenRouter $10 unlock: spend it?
10. Kaggle for wake-word training with own-voice data: acceptable?
11. International GCP `e2-micro`: needed shell-level node, or do managed
    synthetics already cover the requirement?
12. ~~Training runner proof~~ — **Modal batch evaluation completed; production
    training remains local pending a sanitized export boundary.**
13. ~~Private-repo scanning pilot~~ — **Trivy landed in the initial repositories;
    add Semgrep only for a demonstrated source-analysis gap.**

## 9. Sources

Quotas were first checked 2026-07-01/02 and the category catalog was rechecked
2026-07-24. Primary references:

- [OCI Always Free resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)
  — current A1 allowance is 2 OCPUs / 12 GB, 200 GB combined block storage;
  Oracle explicitly describes host-capacity errors as temporary and recommends
  retrying later.
- [OCI compute capacity reports](https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/compute/compute-capacity-report/create.html)
  — reports describe capacity available for instance creation at report time.
- [Google Cloud Free Tier](https://docs.cloud.google.com/free/docs/free-cloud-features)
  — Compute Engine, Cloud Run, Functions, Storage, Firestore, BigQuery, Pub/Sub,
  Secret Manager, and Observability quotas.
- [AWS serverless free offers](https://aws.amazon.com/free/serverless/) and
  [database free offers](https://aws.amazon.com/free/database/) — Lambda,
  SQS/SNS, DynamoDB, and Aurora DSQL; EC2 is time-limited.
- [Azure free services](https://azure.microsoft.com/en-us/pricing/free-services/)
  — Container Apps, Functions, Static Web Apps, SQL, Cosmos DB, DocumentDB,
  integration, identity, and AI API quotas.
- [Koyeb instance limits](https://www.koyeb.com/docs/reference/instances) and
  [database limits](https://www.koyeb.com/docs/databases) — scale-to-zero,
  missing volumes, and five PostgreSQL compute hours.
- [Cloudflare Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/),
  [R2 pricing](https://developers.cloudflare.com/r2/pricing/),
  [D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/), and
  [Workers AI pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/)
  — edge, storage, database, and inference quotas.
- [Cloudflare Vectorize pricing](https://developers.cloudflare.com/vectorize/platform/pricing/)
  and [Tailscale pricing](https://tailscale.com/pricing) — vector and private
  connectivity quotas.
- [Backblaze B2 free allowance](https://help.backblaze.com/hc/en-us/articles/360015521773-Saving-Files-to-B2-from-Computer-Backup)
  — 10 GB storage and 1 GB/day download.
- [DigitalOcean Functions](https://www.digitalocean.com/pricing/functions) and
  [App Platform](https://www.digitalocean.com/pricing/app-platform) — functions
  and static sites only; no free Droplet.
- [Heroku free-plan removal](https://help.heroku.com/RSBRUH58/removal-of-heroku-free-product-plans-faq)
  — free dynos and data services ended in 2022.
- [Grafana Cloud pricing](https://grafana.com/pricing/?tab=free),
  [UptimeRobot pricing](https://uptimerobot.com/pricing/),
  [Better Stack pricing](https://betterstack.com/pricing),
  [Healthchecks.io pricing](https://healthchecks.io/pricing/), and
  [Honeycomb pricing](https://www.honeycomb.io/pricing) — monitoring catalog.
- [Cloudflare CT Monitoring](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/certificate-transparency-monitoring/),
  [GitHub security feature availability](https://docs.github.com/en/code-security/getting-started/github-security-features),
  [Semgrep pricing](https://semgrep.dev/pricing/), and
  [Snyk pricing](https://snyk.io/plans/) — security catalog.
- [Trivy Action](https://github.com/aquasecurity/trivy-action) and
  [March 2026 Trivy advisory](https://github.com/aquasecurity/trivy/security/advisories/GHSA-69fq-xp46-6x23)
  — supported scans plus the required pinning/remediation boundary.
- [PlanetScale plans](https://planetscale.com/docs/planetscale-plans),
  [Neon pricing](https://neon.com/pricing),
  [CockroachDB pricing](https://www.cockroachlabs.com/pricing/), and
  [Turso pricing](https://turso.tech/pricing) — current relational database
  free-tier status and allowances.
- [Zilliz free cluster](https://docs.zilliz.com/docs/free-trials),
  [Qdrant free cluster](https://qdrant.tech/documentation/cloud/create-cluster/),
  [Pinecone pricing](https://www.pinecone.io/pricing/), and
  [Upstash Vector](https://upstash.com/docs/vector/overall/getstarted) —
  hosted vector catalog and inactivity behavior.
- [Kaggle GPU usage](https://www.kaggle.com/docs/efficient-gpu-usage),
  [Lightning AI pricing](https://lightning.ai/pricing/),
  [Modal pricing](https://modal.com/pricing),
  [Colab FAQ](https://research.google.com/colaboratory/faq.html), and
  [Hugging Face ZeroGPU](https://huggingface.co/docs/hub/main/en/spaces-zerogpu)
  — free training/accelerator catalog.
- [Groq rate limits](https://console.groq.com/docs/rate-limits),
  [GitHub Models billing](https://docs.github.com/en/billing/concepts/product-billing/github-models),
  and [OpenRouter FAQ](https://openrouter.ai/docs/faq) — managed inference.

Before implementing any phase, re-verify the provider quota, inactivity policy,
privacy terms, region, and billing prerequisite. Flagged low-confidence:
Grafana Cloud over-quota behavior, Azure DocumentDB/SQL billing boundaries,
Cloudflare card-required flags, and Vultr program availability.
