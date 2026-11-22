# Argus Grafana reader: prepared identity and bounded handoff

**Status:** source preparation only; live role approval, apply, token issuance,
Vault write and runtime restart have not occurred. **Revision:** 3, 2026-11-22.
**Human seed:** “use argus credentials to check open alerts on grafana. Lets amend”.

## Outcome and why

The requested alert inventory is blocked: `GRAFANA_RO_TOKEN` is empty in both
Argus's process and Vault-rendered environment. Read-only provisioning discovery
reported Grafana 13.3.0 Open Source, organization `1` (`Main Org.`), and zero
service accounts. The existing webhook HMAC authenticates inbound events; it
cannot read Grafana alerts. No historical alert count is current evidence.

This component prepares exactly one identity, `svc-argus-grafana-alert-reader`,
in organization 1. **OSS `Viewer` is broader than alerts:** it includes dashboard and notification-resource read access and the ability to
query data sources. It is not an alerts-only
credential. The user must accept that broader access before identity creation or
token issuance. No Editor/Admin role, custom authorization service or permanent
admin identity is proposed. See [Grafana's OSS alerting permissions](https://grafana.com/docs/grafana/latest/alerting/set-up/configure-roles/).

## Source and boundaries

`components/grafana/environments/home/argus-reader` uses the existing shared
MinIO backend and OpenTofu encryption. Its state object is
`components/grafana/environments/home/argus-reader/terraform.tfstate` in
`tofu-state`. Provider `grafana/grafana` is pinned to 4.55.0 with its signed
checksums. Authentication is a sensitive ephemeral provider input, supplied as
`GRAFANA_BOOTSTRAP_AUTH`; it is never a resource attribute or output. The module
requires OpenTofu >=1.11; installed 1.12.3 and CI-pinned 1.12.1 support this input.
Only account metadata and its ID belong in state; **no token resource exists**.
`prevent_destroy` guards ordinary destruction while this configuration exists;
it is not protection against removing the resource block or out-of-band deletion.

The unit is excluded from scheduled drift and absent from the merged-main apply
fixture. Source merge cannot adopt it into unattended execution. Identity changes
belong to IaC, values to Vault, Argus lifecycle to Desktop. No GitOps runtime
change is needed. Keep this manual until a reviewed nonhuman management credential
and zero-diff plan justify separate adoption.

## Prepared execution sequence — pending authorization

1. Confirm current organization, zero matching accounts and the approved source
   revision. If an account appeared, stop and review an import; do not create a
   duplicate. Use the existing private bootstrap credential flow, TLS verification,
   and encrypted state access. Do not print credentials, enable debug logging or
   put values in arguments. Bootstrap admin authentication is limited to this
   bounded operation, never installed in Argus or stored as unattended identity.
2. In the environment directory, run `terragrunt run -- plan -out=argus.tfplan`.
   Inspect the encrypted plan locally: exactly one Viewer account creation in
   organization 1, no other resource actions. Apply only that reviewed plan with
   `terragrunt run -- apply argus.tfplan`, then verify account name/ID/role/org.
   `service_account_state_id` is the composite Terraform identity, not the API ID.
   Resolve the numeric ID through Grafana's service-account search; require one
   exact name match with organization 1 and Viewer role, then verify the positive
   integer ID through `GET /api/serviceaccounts/{id}` before token issuance.
   Do not parse Terraform identity text into the token endpoint.
   Supply the same ephemeral bootstrap input again at apply; it is not saved.
   A second plan must show no changes. Keep plans private and ignored.
3. Separately issue one token for that exact account using
   `POST /api/serviceaccounts/{id}/tokens`. Proposed name:
   `argus-alert-baseline-20261122`; proposed `secondsToLive`: `86400`.
   Approve this 24-hour investigation lifetime explicitly; it is not unattended
   renewal. Capture the one-time value in memory only. Keep only ID, name and
   expiry in the receipt. If issuance returns an ambiguous failure, inspect token
   metadata before retrying; do not blindly create another token.
4. Read Vault KV-v2 `secret/data/home/hermes` into memory, including its metadata
   version. Require exactly one `GRAFANA_RO_TOKEN=` line in `ARGUS_ENV`; reject
   missing/duplicate keys or multiline token values. Replace only that line and
   preserve every other byte of the environment and every sibling document key.
   Submit `POST /v1/secret/data/home/hermes` with
   `{"options":{"cas":<observed version>},"data":<preserved map with updated ARGUS_ENV>}`.
   CAS conflict stops: reread and reconcile, never overwrite newer work. Verify
   readback equals the intended token in memory; emit only success booleans.
   **Do not run `seed-hermes-vault`: it reseeds whole payloads from older Sops.**
5. Wait for the existing Vault Agent render and verify the key in memory and
   file permissions. Through the approved Desktop transport, run
   `just stop-hermes-argus`, `just start-hermes-argus`, then
   `just verify-hermes-secret-renders`. These recipes currently use direct SSH;
   resolve the observed direct-connection failure or review a proxy-capable
   transport first. Do not replace the recipes with raw service changes.
6. From Argus, verify the actual account identity and permissions, then GET
   `/api/alertmanager/grafana/api/v2/alerts?active=true` and
   `/api/prometheus/grafana/api/v1/rules`. No auth redirects or TLS bypasses.
   Record UTC time, statuses, counts, safe labels, onset/suppression and rule
   error/no-data states. Permission failures are unknown coverage, not zero alerts.
   Generic Hermes health does not test Grafana access. Discord delivery remains
   a separate proof. Recheck before/after approved recovery stages.

## Failure and recovery

Stop on any failed gate. If issuance/handoff fails, revoke **only the token issued
by this operation**, using its verified ID; do not delete the account or unrelated
tokens. If Vault was changed, restore only the prior token line using a fresh CAS
and only if its current value still equals this operation's value; preserve
concurrent sibling edits. A successfully restarted process needs the supported
Argus restart again after restoration. Revocation/restoration/restart are part of
the explicit live authorization, not implied by preparing this document. Retain
private encrypted state; never destroy it as rollback. Schedule a pre-expiry
follow-up if continued access is needed; no renewal is implemented.

## Evidence and limits

The first contract run failed on the absent bootstrap exclusion and absent
metadata-only resource, before implementation. Offline validation uses the real
pinned provider schema with a mock provider: Viewer/org assertions and rejection
of invalid organization IDs. It proves configuration behavior, not live Grafana
permissions, token lifecycle, Vault CAS handling or notification delivery. The
contract executes the real drift runner against a captured command adapter and
checks that the account unit cannot join unattended execution. Those live steps
remain pending. Kepler control-plane recovery has since completed; cp-1 boot
cleanup and a host reboot remain outside this credential operation's scope.

Observed validation: both initial contract assertions failed before implementation;
all 67 reader/drift/apply regression cases and both mock-provider plan tests now
pass. The real pinned provider schema validates both the module and generated
sensitive ephemeral authentication configuration. Offline Terragrunt rendering
confirms the backend key and organization 1. Formatting, TFLint 0.64.0 (the CI
pin), and diff checks pass.
Independent review found that the provider exports a composite Terraform ID;
revision 2 names it explicitly and resolves the API ID through verified metadata.
The first draft is retained in the private task receipt `/tmp/argus-reader-draft-1.md`;
RED/GREEN/regression logs are `/tmp/argus-reader-{red,green,regression}.log`.
No live identity, token, Vault or runtime mutation was performed.


### CI integration correction

CI run `45042516112` on PR #179 (`bedebd8`) reported one failed Bats case:
`S01 shared-root canary contract`. The source added a tracked Terragrunt unit
without registering its state key in `tests/fixtures/state-keys.txt`; the earlier
67-case focused run did not include this repository-wide inventory contract.
A local rerun reproduced the exact assertion failure before the fix.

The correction adds only the new unit's already verified backend key to the
inventory. Removing that single new line reproduces the previous fixture byte
for byte: no existing unit or state key changed. The strict inventory assertion
is unchanged; the Grafana drift exclusion and unattended-apply fixture remain
unchanged. Focused S01 and all **176 Bats cases** pass. The first full local run
also exposed an uninitialized LiteLLM provider submodule in this linked worktree;
CI already initializes submodules. Initializing the exact recorded commit
`6837ca9a731a40146ae00cfc0f23f34eabed6cec` fixed that local prerequisite without
changing the gitlink or provider source. This setup failure is not an implementation
RED anchor. The full-suite retry used the normal Go module cache across Bats's
isolated HOME directories, matching the CI cache separation.

The CI provider-bootstrap, optimized-Python Apollo route, Discovery routes and
Tailscale identity scripts also pass. Receipt logs are
`/tmp/argus-reader-ci-{red,focused-green,all-bats,all-bats-final}.log`;
`all-bats` preserves the local prerequisite failure and `all-bats-final` records
176 passes. No contract was weakened, no existing state key changed, and no live
resource, credential or backend mutation occurred.


### Hosted review reconciliation

Hackerman's review of `bedebd8` found a P2 in the source-only token guard:
recursive scanning also counted generated `.terragrunt-cache` and `.terraform`
files. Harmless cached token-resource fixtures reproduced the assertion failure.
The scanner now excludes those two directory segments only; account/token
resources in actual source remain subject to the unchanged exact-resource check.
The fixtures are retained inside the contract and automatically cleaned up.
Focused RED/GREEN receipts are `/tmp/argus-reader-cache-{red,green}.log`.
Independent targeted review verified byte-preserved existing state keys,
unchanged unattended scope and exact cache exclusions, with no remaining blocker;
the reviewer did not independently rerun Bats. The final complete Bats rerun after
this correction passed **176/176**, recorded in
`/tmp/argus-reader-ci-all-bats-reviewed.log`. This evidence does not authorize
live bootstrap or change runtime behavior.
