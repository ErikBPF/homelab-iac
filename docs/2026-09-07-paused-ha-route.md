# Paused household HA inference route

**Status:** Source and exact one-route deletion plan verified; apply pending.

Household inference is explicitly suspended after the Kepler/Apollo GPU exchange.
Withdraw `ha-agent-qwen4b` from the active production model manifest so LiteLLM
does not advertise Kepler's stopped `8088` backend. Keep the HA harness key and
OpenBao handoff resources, model files, and Compose definition. This change does
not move inference to Apollo or start any inference service.

The previous route definition remains in Git at
[`62c1539`](https://github.com/ErikBPF/homelab-iac/blob/62c1539/components/litellm/environments/home/production/models.json).
Resuming requires an explicit workload placement decision and a working backend
before restoring the alias and its Servarr expected-catalog entry.

## Contract and verification

- Active Terraform inputs omit only the paused HA alias; `qwen-chat` remains a
  promised chat route. HA credential resources remain declared.
- Servarr removes the same alias from its expected probe catalog, retaining
  all thirteen other probes without adding skips.
- Desktop's semantic canary requires a connected database and an actual
  `qwen-chat` completion. Failed DB checks or empty completions still fail.

The IaC pause test and S05 catalog fixture run under `bats tests/*.bats` in CI.
Servarr's Discovery P1 tests and Desktop's executable semantic-probe tests cover
their consumer boundaries. Pause tests were observed failing before source edits.

## Rollout

Merge IaC first, then Servarr and Desktop consumer changes. Use the existing
stored provider identity and state credentials; do not bootstrap or rotate keys.
Plan only `components/litellm/environments/home/production`; inspect a value-free
action summary and require exactly one deletion:
`litellm_model.this["ha-agent-qwen4b"]`. Apply the reviewed saved plan only.
Any unrelated change requires separate reconciliation before proceeding.

The 2026-09-07 read-only plan contains exactly that deletion, with no additions
or updates. The live catalog still contains seventeen aliases before apply;
`qwen-chat` returned HTTP 200 with a completion during the preflight.

Pull the merged Servarr revision on Discovery. Preview the Desktop Discovery
activation and preserve the live kernel and unrelated services before deploying
its probe. Verify HA is absent from `/v1/models`, an authenticated `qwen-chat`
completion succeeds, and `litellm_semantic_ready` becomes `1`. Existing failure
alerts remain enabled. A passing canary covers that route and the gateway DB;
the full Servarr catalog probe covers the other promised routes.

Recovery keeps household inference stopped and HA excluded. Diagnose and fix
the `qwen-chat`/DB failure, or select another explicitly promised, verified route;
do not revert the canary to the paused HA backend. Restore the HA alias and
catalog entry only after its backend is explicitly resumed and verified.
Never delete credentials or model data.
