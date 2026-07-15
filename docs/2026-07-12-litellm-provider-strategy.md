# LiteLLM Terraform provider strategy

**Status:** Implemented — v1.1.1 metadata and lifecycle parity verified; production cutoff remains in S05

## Reader and action

This decision is for the engineer implementing LiteLLM infrastructure ownership. After reading it, they should be able to patch, test, publish, and safely adopt a provider version without moving production models out of YAML early.

## Decision

Keep `homelab-iac` as the consumer and infrastructure source of truth. Do not vendor provider source into this repository.

Patch the official LiteLLM Terraform provider in the temporary public fork `ErikBPF/terraform-provider-litellm`, publish it as `registry.terraform.io/ErikBPF/litellm`, send the same changes upstream, and pin the forked release until an upstream release passes the same acceptance suite. The fork is a delivery bridge, not a permanent API divergence.

The IaC repository pins the provider repository as a Git submodule only for offline acceptance tests. Provider implementation and release history remain owned by the provider repository; copied provider source is forbidden.

Production LiteLLM models remain YAML-owned until all acceptance gates pass. A provider that can create a model but cannot recover ownership after state loss is not suitable for the hard cutover.

## Required provider contract

The model resource must support:

- import by LiteLLM model UUID;
- create, read, update, delete, refresh, and zero-diff import round trips;
- optional team ownership for future Enterprise use; LiteLLM OSS leaves it empty;
- context and output token limits;
- input and output modalities;
- reasoning and tool-call capabilities;
- pricing and routing base models without conflating them;
- lossless supported `model_info` fields needed by the production catalog;
- sensitive API-key references without returning plaintext into logs or configuration;
- authoritative API read-back instead of preserving stale state for values the API returns.

Privacy classification and lifecycle are local governance metadata, not claims made by LiteLLM. They remain in the normalized catalog/module contract unless LiteLLM gains an explicit, lossless metadata namespace.

## Authentication boundary

`key_type = management` limits routes but does not grant model-administration authority. Live evidence confirmed that an `internal_user` management key receives HTTP 403 on model creation, and team-scoped model administration requires LiteLLM Enterprise.

The OSS boundary therefore uses a dedicated proxy-admin bootstrap credential for provider model CRUD. It remains sops-encrypted; Terraform must not manage the value used to authenticate its own provider. The model module retains optional `team_id` for future Enterprise adoption, but the OSS canary leaves it empty and the provider omits it from requests.

The proxy-admin credential must be narrowly operational: used only by the explicit Terraform workflow, rotated after bootstrap or suspected exposure, and unavailable to workloads. This is an OSS constraint, not a claim of least privilege.

## Delivery sequence

1. Add provider unit tests that fail for missing import and metadata round trips.
2. Implement the importer and typed fields with API read-back.
3. Run `go test ./...` in the provider repository with dependencies locked by `go.sum`, then run its acceptance suite against a disposable LiteLLM 1.91.2 instance.
4. Tag a semantic version, publish the GoReleaser checksums and signature through GitHub Releases, publish the provider version through the Terraform Registry, and pin its exact version plus artifact SHA-256 in the IaC repository.
5. Rerun the disposable live canary with the dedicated proxy-admin bootstrap identity; leave `team_id` empty on OSS.
6. Require create, read, update, import, delete, and repeated zero-diff plans.
7. Open the upstream contribution with the same tests.
8. Migrate production aliases only after catalog parity produces no dropped fields.

Release v1.1.1 is built from commit
`19158c1f277643f6d69421aef320f85ad9c52016`. Its Linux amd64 artifact and
RSA-4096 signing fingerprint are pinned in
`components/litellm/provider-source-lock.json`; the public key is
`components/litellm/provider-signing-key.asc`. GitHub release publication and
signature verification pass. The provider is published at
`registry.terraform.io/ErikBPF/litellm`; OpenTofu verified its developer
signature and the registered artifact passed the full disposable LiteLLM 1.91.2
lifecycle. v1.1.1 also adopts API-populated catalog defaults without perpetual
diffs; the regression was observed live with `max_tokens = 204800`, locked RED,
then proven zero-diff after release.

The canonical LiteLLM mapping is `max_input_tokens`, `max_output_tokens`,
`input_modalities`, `output_modalities`, `supports_reasoning`,
`supports_function_calling`, `supports_vision`, `input_cost_per_character`,
`default_voice`, `probe_language`, `probe_text`, `probe_skip`, and `max_tokens`
under `model_info`. The provider proves these names against the pinned LiteLLM
API fixture and reads them back from the API. Local `privacy_tier` and
`lifecycle` fields never enter that payload.

## Failure and recovery

Never remove a production resource from state to test import until importer support has passed offline and disposable live tests.

If create succeeds but state ownership is lost, identify the model by UUID, delete only the disposable model through the authenticated model-delete API, then verify both remote inventory and state are empty. Do not reapply blindly; that can create a duplicate alias with a new UUID.

## Exit from the fork

Switch back to the official provider when an upstream release contains the required contract and passes the repository canary unchanged. The migration is a provider source/version change followed by init, refresh, and zero-diff plan; it must not recreate LiteLLM resources.
