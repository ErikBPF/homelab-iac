# Dedicated LiteLLM provider bootstrap

**Status:** Implemented and tested offline; live creation requires review.

Terraform provider credentials are bootstrap material. Store them in this
repository's encrypted dotenv, never in a workload environment or Terraform
state. The provider supports `LITELLM_API_BASE` and `LITELLM_API_KEY` natively.

Preview the exact request without network access:

```sh
python3 components/litellm/scripts/bootstrap-provider.py
```

The request creates only `svc-homelab-iac-litellm-control-plane-manager`,
with a matching key alias, `proxy_admin` role, and a 30-day credential.
Proxy-admin access is broad: it is the existing OSS provider strategy,
not model-scoped access. This identity is for explicit operator-driven
Terraform work, not unattended workloads.

After reviewing the request, pass the sanctioned LiteLLM operator bootstrap
credential on stdin to the same command with `--apply`. Use the existing
OpenBao operator path or a purpose-named `*.secrets.json` handoff; never paste
the credential into chat or put it in command arguments.

The command rejects an existing provider identity or dotenv configuration.
It creates the user/key, verifies encrypted dotenv round-trip, and atomically
replaces only ciphertext. Existing dotenv values are preserved. If persistence
fails, it attempts to delete only the key and identity created by this call.
A failure requires inspecting that named identity before retrying; an API
timeout can leave creation outcome uncertain.

The new credential is not printed. Review and commit the SOPS diff. Reload
the operator environment from encrypted dotenv before the authenticated
DeepSeek key plan. Existing plaintext `.env` files are not silently rewritten.
A 30-day key requires a reviewed rotation before expiry; this bootstrap command
intentionally refuses to rotate an existing identity.

No LiteLLM model, inference key, or runtime secret is created by preview.
The authenticated DeepSeek key plan and runtime handoff remain separate
reviewed operations.

Checks:

```sh
python3 tests/litellm-provider-bootstrap.py
```

See [provider strategy](2026-07-12-litellm-provider-strategy.md) and the
[human review gate](2026-07-12-infrastructure-ssot-implementation-plan.md).
