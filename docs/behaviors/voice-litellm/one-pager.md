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
