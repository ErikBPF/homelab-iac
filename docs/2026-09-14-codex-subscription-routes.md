# Personal Codex subscription routes

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
