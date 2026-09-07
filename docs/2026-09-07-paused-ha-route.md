# Paused household HA inference route

**Status:** HA route withdrawn and API verified; Discovery consumer rollout pending.

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

The 2026-09-07 read-only plan contained exactly that deletion, with no additions
or updates. The live catalog contained seventeen aliases before apply;
`qwen-chat` returned HTTP 200 with a completion during the preflight.

The first apply removed the managed HA deployment. API readback exposed one
additional deployment of the same alias and Kepler backend, outside that state
address. It was imported into the now-empty HA address using the original route
variables, then removed through a second reviewed one-deletion plan. Both
applies changed no other resources. Final API readback has sixteen aliases,
no HA alias, and a `qwen-chat` completion returned HTTP 200.

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

## Discovery drift scope during the pin refresh

Discovery's old `dc54f16` pin monitored 23 units. Later source introduces Harbor
and credential handoff units whose runtime credentials are not all available
to that service. Refresh the published IaC pin with explicit exclusions that
preserve exactly those 23 monitored units, including the corrected production
LiteLLM catalog. The fixture `tests/fixtures/drift-monitored-units.txt` rejects
both accidental scope expansion and loss of existing coverage.

The new excluded units are Authentik `iac-access`, Harbor `fleet-readers`,
`production`, `project-members`, LiteLLM `deepseek-harness-key`, and OpenBao
`authentik-runtime`, `deepseek-harness-litellm`, `harbor-project-iam`.
Existing Telstar, canary and secret-foundation exclusions remain in place.
These units are explicitly outside scheduled drift coverage until a separate
credential-adoption gate verifies access and zero-diff plans; remove their
exclusions and update the scope fixture together then. No whole-repo clean
claim follows from this bounded monitor.
