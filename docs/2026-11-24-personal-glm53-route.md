# Personal full GLM 5.3 route

**Status:** Prepared and verified offline. No live model, key, or workload changed.

## Outcome and reason

The requested personal shortlist uses DeepSeek V4.1 Flash and full GLM 5.3.
The existing gateway declared only GLM 5.3 Flash. This change adds the full
model without removing the Flash route used by other clients.

The reviewed source is the OpenCode Go model API at
<https://opencode.ai/inference/go/v1/models>, read on 2026-11-24. It reports
1,000,000 context tokens, 131,072 output tokens, reasoning and tool support,
and input/output/cache-read prices of $1.40/$4.40/$0.26 per million tokens.
The new route uses the published OpenAI-compatible endpoint and the existing
`os.environ/OPENCODE_GO_KEY` reference. No secret enters the declaration.
Scheduled probes remain disabled for this subscription route.

## Changes and evidence

The production manifest, exact alias fixture, reviewed exception, and personal
allowlist fixture include `glm-5.3`. Other consumer fixtures do not receive it.
The existing bounded key helper accepts an optional `glm-5.3` scope. Its
default still grants or revokes only the four Codex aliases. The helper retains
the exact personal key alias, SHA256 fingerprint, concurrent-change check,
post-write verification, and rejection of unrestricted or empty allowlists.

RED: the new route test failed with `Full GLM 5.3 route is missing`.
GREEN: `python3 tests/glm53-personal-route.py`, the existing Codex route test,
and `bash tests/infra-ssot-contract.sh s05` pass. The S02 provider contract,
OpenTofu format check, Terragrunt format check, and `git diff --check` pass.
`shellcheck` is unavailable in the current shell.

## Continuing work and recovery

Review a saved plan for only
`components/litellm/environments/home/production`. It must add exactly one
model and show no unrelated changes or destruction. Apply only that reviewed
plan with the existing provider and encrypted-state credentials.

Servarr must separately publish and deploy its `glm-5.3` session-header
forwarding entry before end-to-end validation. Then grant the personal key:

```sh
ssh -o Hostname=192.168.10.210 discovery \
  'docker exec -i litellm python - grant <key-sha256> glm-5.3' \
  < scripts/codex-key-access.py
```

Use `revoke` with the same scope before removing this route through OpenTofu.
Do not remove the Flash route, rotate the personal key, or change other grants.

The four existing Codex aliases remain declared. Tiny authorized live probes
returned HTTP 400 for Astra Responses and HTTP 502 for Luna Chat. Alias presence
and passing offline contracts therefore do not prove live Codex availability.
