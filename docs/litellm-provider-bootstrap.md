# Dedicated LiteLLM provider bootstrap

**Status:** Created and rotated live on 2026-09-07; offline regression checks pass.

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
Rotate before the 30-day expiry. Preview with:

```sh
python3 components/litellm/scripts/bootstrap-provider.py --rotate
```

After review, pass the operator credential on stdin with `--rotate --apply`.
Rotation creates a replacement for the same identity, authenticates it, verifies
and atomically persists SOPS ciphertext, then revokes the previous key and checks
that it is rejected. Persistence failure removes only the replacement. A failure
after persistence leaves the new credential saved; inspect old-key revocation
before retrying. Commit the encrypted change and reload the operator environment.

Terragrunt dependency output reads require `TF_VAR_state_passphrase`. The devenv
shell maps it from `UNIFI_STATE_PASSPHRASE` at runtime so encrypted dependency
state can be read without putting the passphrase into Nix evaluation.

No LiteLLM model, inference key, or runtime secret is created by preview.
The authenticated DeepSeek key plan and runtime handoff remain separate
reviewed operations.

Checks:

```sh
python3 tests/litellm-provider-bootstrap.py
```

See [provider strategy](2026-07-12-litellm-provider-strategy.md) and the
[human review gate](2026-07-12-infrastructure-ssot-implementation-plan.md).
