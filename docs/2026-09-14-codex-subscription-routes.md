# Personal Codex subscription routes

Astra requires `mode: responses` and an explicit `reasoning_effort` allowlist.
LiteLLM 1.100.1 lacks its ChatGPT model metadata: chat mode chooses the wrong
endpoint, while incomplete metadata can disable the streaming required by
Codex. Router registration from the model information restores the native
Responses path. Provider 1.2.3 adds this mode to its validation schema.
Provider 1.2.4 also emits the bare model name alongside the explicit provider.
Combining a prefixed model with an explicit provider registered Astra metadata
under `chatgpt/chatgpt/gpt-6-astra`, while inference looked up the single-prefix
key and incorrectly used the chat endpoint. The corrected representation is
`model: gpt-6-astra` with `custom_llm_provider: chatgpt`.

Existing Astra requires a saved Terraform plan with
`-replace='litellm_model.this["codex-gpt-6-astra"]'` to rewrite its stored
representation. Readback normalizes model names, so an ordinary plan cannot
detect this representation change. Replacement retains the public alias and
personal key grants. The legacy `/model/update` endpoint also ignores model
metadata; verify the stored mode after metadata changes rather than relying
only on a successful apply.
The other three model routes remain unchanged.
The four output limits preserve the gateway's existing advertised value of
128000 tokens; OpenCode retains its separate 32768-token output reservation.
These are configured metadata, not a measured subscription output maximum.

The user requested the saved device login be activated on the private home
LiteLLM gateway and exposed to the personal OpenCode profile. Four explicit
`codex-<upstream-model>` aliases use the native `chatgpt` provider: GPT-6 Astra,
GPT-5.6 Luna/Sol/Terra. Other account models are excluded at the user’s request.
API keys and base URLs are empty: the provider obtains OAuth credentials from the runtime-owned auth store.

These manually exercised routes skip scheduled probes to avoid unattended
subscription consumption. No subscription credentials enter Terraform state.
Servarr owns the persistent login mount and refresh coordination. Runtime must
be ready before these routes are applied.

Plan only `components/litellm/environments/home/production` with the existing
provider and encrypted-state credentials. Require exactly four model additions;
inspect any unrelated drift before applying the saved plan. Do not reconcile
unmanaged experimental rows. Validate chat, streaming and tool use through the
personal OpenCode key before claiming activation.

Grant the four models to the existing `opencode-20260713` key using its SHA256
fingerprint, never its secret value:

```sh
ssh -o Hostname=192.168.10.210 discovery \
  'docker exec -i litellm python - grant <key-sha256>' \
  < scripts/codex-key-access.py
```

The script preserves other models, budgets and credentials, verifies the key
alias and refuses unrestricted/empty allowlists. Rollback uses `revoke` through
the same entry point before removing the four routes through Terraform. It does
not remove the saved login. No other harness key receives subscription access.

Offline check: `python3 tests/codex-subscription-routes.py`.
