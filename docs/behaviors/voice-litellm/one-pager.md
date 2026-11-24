# Voice model routing — deployed

**Stage / revision:** RV / 3
**Status:** Aliases, scoped key, OpenBao policy and KV applied; primary ASR qualified, rewrite degraded.
**Owner / date:** homelab-iac / 2026-11-21

The user's gateway-first/local-fallback request is deployed. Saved plans created only two aliases and one scoped key. `voice-transcribe` uses `openai/aTrain-core/faster-whisper-large-v3-turbo` at Orion:9000/v1; its provider prefix was corrected by a single-model update after the unprefixed route returned HTTP400. `voice-rewrite` uses existing `qwen3.8-coder` at Orion:8080/v1. Both have typed `no-log=true`, zero configured inference prices and no paid route.

The identity `svc-homelab-iac-voice-dictation-model-inference` permits exactly those aliases, parallelism two and 20 requests/minute. An unrelated alias returned HTTP403. Key metadata `store_prompts_in_spend_logs="false"` is normalized by LiteLLM 1.110.2. Client request limits disable retries and gateway fallback.

The initial normal AppRole foundation request correctly returned HTTP403. Following the user's instruction to create/register/use credentials through IaC, the existing sanctioned Sops bootstrap secret applied the narrow policy change. The saved plan preserved the live Cloudflare read grant and added only voice data create/update/read and metadata read. Normal AppRole then applied `secret/home/voice-litellm`; its `VOICE_LITELLM_API_KEY` was privately compared and installed mode0600 on Endeavour. No value is in these records or Nix outputs; encrypted key state owns the generated secret. The writer cannot edit its own policy.

The approved Servarr merge exception required a targeted temporary `allow_merge_commit` change. PR363 merged, then the setting was restored and verified false, with squash enabled. Orion pins the exact voice-only artifact. Tailscale assertions add no permission; live Discovery access and Endeavour denial passed without applying an ACL widening.

Six existing key contracts and formatting checks passed. Gateway English/Portuguese ASR and installed synthetic controller E2E passed; forced local fallback and cancellation passed. Orion GPU rewrite is unavailable after one bounded owner restart, so contextual mode uses local Ollama.

Privacy limits remain: a failed rewrite had one identifiable spend row with no synthetic marker, but successful ASR lacked an identifiable accounting row; Langfuse queries timed out. Configuration and these probes do not prove universal diagnostic-content exclusion. Source integration remains pending. Preserve encrypted key state and OpenBao as credential owners; do not recreate or rotate the working key just to reconcile source.

## PR180 review reconciliation — 2026-11-22

Accepted the missing Discovery alias fixture/count and state-key registrations; their existing contracts reproduced RED before correction. Both voice units remain explicitly excluded from the unattended drift/apply scope until that runner's credentials and zero-diff plans are verified. Interactive successful applies do not prove unattended readiness. The monitored-unit fixture remains unchanged because adoption is deferred deliberately, not omitted.

Confirmed `qwen3.8-coder` in [the pinned Servarr source](https://github.com/ErikBPF/servarr/blob/f991f2cfe84bfd43f14aa47c147439704ebcfa79/machines/orion/ai-models.compose.yml#L40). The model name is correct; readiness was overstated by the production lifecycle. Changed it to `manual`, retained `probe_skip` for the unavailable endpoint and the scoped key allowlist so the accepted gateway-attempt/local-fallback behavior is preserved. Lifecycle is local catalog metadata, not passed to the provider. No endpoint mutation, credential rotation or new apply was performed. Promotion requires a successful rewrite qualification and an explicit probe decision.

Validation after reconciliation: all 176 Bats contracts passed with the pinned provider submodule initialized; exact alias/state/drift assertions remain enforced. Independent review found no remaining material concern. [Repair and validation receipt](cr-validation.txt). Fresh automated review is requested after publication.

## Voice credential regression contract — 2026-11-22

Added the requested offline voice-key contract: exact alias allowlist, identity, budget/rate/concurrency limits, local/privacy metadata, OpenBao dependency and field, exact policy grants, and absence from unattended adoption. All seven key contracts passed. Two bounded mutations proved the new test rejects an added paid alias and a removed writer grant; both mutations were restored immediately. No runtime credential or policy changed. Independent reviewer `voice_research_review` checked this diff and reported: “IaC contract covers scoped aliases, limits, privacy metadata, exact handoff, and deferred monitoring.” The reviewer did not execute Bats; the execution results here are from the primary agent.
