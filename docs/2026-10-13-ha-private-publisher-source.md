# HA private publisher: source prepared, unprovisioned

## Outcome and authorization

The private `ha-harness` project and its project-scoped image publisher are
declared in the existing Harbor fleet-readers state. This stage changes local
source and tests only. It does not provision a project, issue credentials, or
publish an image.

The human seed is preserved verbatim: `continue`, `Publish source + artifact`,
`Private Harbor via IaC`, `Existing fleet readers`, `Current workstation`.
Source PR publication is authorized in the parent delivery task. This record
does not authorize provisioning, credential access or live deployment. Separate
IaC plan/apply approval remains pending; no image has been published.

## Changes and decisions

- [Fleet-readers resources](../components/harbor-iam/modules/fleet-readers/main.tf)
  own the private project and publisher together. `public = false` and
  `prevent_destroy = true` protect the project. Scanning and SBOM settings
  follow the existing library convention; Cosign pull enforcement stays off.
  These attributes are supported by the pinned
  [Harbor 3.12.4 project schema](https://github.com/goharbor/terraform-provider-harbor/blob/v3.12.4/docs/resources/project.md).
- The robot uses `svc-ha-harness-harbor-image-publisher`, project scope,
  repository pull/push only, and 365-day expiry. Its namespace references the
  project resource directly, establishing create ordering.
- [Independent controls](../components/harbor-iam/modules/fleet-readers/variables.tf)
  default `ha_harness_publisher_rotation_generation` to 1 and
  `ha_harness_publisher_disabled` to false. Existing reader/Cognee rotation is
  unchanged. An ephemeral password flows only into Harbor `secret_wo` and
  Vault `data_json_wo`, using the same independent generation.
- Vault stores only `HARBOR_PUBLISHER_USERNAME` and `HARBOR_PUBLISHER_SECRET`
  at `secret/home/ha-harness-harbor-publisher`. The username comes from provider
  `full_name`, retaining Harbor's required project qualifier.
- The [existing writer policy](../components/openbao/modules/runtime-secret-foundation/main.tf)
  gains only exact HA data create/update/read and metadata read paths. No new
  AppRole, SecretID, wildcard, component, or state unit is added. Existing fleet
  readers, Cognee, public library, OIDC, guest memberships, and host policy are
  unchanged.

## Evidence and limits

Source-review base: `de10bfaa7480da0ded9ecce8e956d3f507a53487`.
Branch: `feat/ha-private-publisher-20261013`.

The [resource-block-scoped Bats contract](../tests/harbor-oidc-contract.bats)
passed 18/18 before edits. Four added tests then failed on the missing
project, robot, ephemeral password, and exact writer path before production
source changed. GREEN passed 22/22. The selected Harbor/OpenBao/GitOps/Authentik
suite passed 32/32. Initial owner full Bats passed 93/94: S04 reported
`S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented`.
The same failure reproduced in the clean same-HEAD archive worktree with an
uninitialized provider. Initializing the exact pinned submodule then exposed an
empty dependency cache, not a missing implementation. After one verified public
dependency download, offline full Bats passed **94/94**. Provider verbose tests
passed 46 top-level unit tests and skipped three acceptance tests because
`TF_ACC` was unset. No live service was contacted. The provider gitlink remains
`6837ca9a731a40146ae00cfc0f23f34eabed6cec`; source and module locks are unchanged.

Checks: `bats tests/harbor-oidc-contract.bats`, `bats tests/*.bats`,
`terraform fmt -check -diff` on the three edited Terraform files,
`terragrunt hcl format --check --diff`, and `tflint --chdir` on both edited
modules. Format and lint passed. Bats used an ephemeral Nix runner; full and
selected suites used an empty environment with mock/fixture credentials.
One runner attempt failed because its pre-Nix PATH omitted Bats; moving PATH
capture inside the Nix shell repaired that infrastructure error, not RED.

Private receipts are under
`/home/erik/.local/share/opencode-v2/tmp/opencode/ha-private-publisher-*`.
Independent source review found no verified issue. These are source/unit checks,
not initialized Harbor provider validation, hosted full CI or live E2E. Final
receipts include `ha-private-publisher-full-bats-public-deps-20261013.log` and
`ha-private-publisher-provider-verbose-20261013.log` in the same private directory.

## Waiting work and recovery

After separate approval, the affected units are
`components/openbao/environments/home/runtime-secret-foundation` first, then
`components/harbor-iam/environments/home/fleet-readers`. Before mutation, verify
whether `ha-harness` or its robot already exists; resolve ownership and review
any import into these exact resource addresses rather than creating duplicates.
Review the private flag, supported live SBOM version (Harbor >= 2.11), exact
publisher permissions, and absence of unrelated changes in the shared state.

If Harbor succeeds but the Vault write fails, repair only the exact writer
permission, then advance only `ha_harness_publisher_rotation_generation` and
reapply the approved unit. Do not advance shared `rotation_generation`: that
would rotate unrelated fleet/Cognee credentials. Do not expect an ephemeral
password to be recoverable from state. Source rollback before provisioning is
limited to this slice; after provisioning, preserve the project and use the HA
disable/rotation controls under renewed scope-appropriate authorization.
