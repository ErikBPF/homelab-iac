# Test contract: infrastructure SSOT hard cutover

**Status:** Red contract for S01 and S02

## Reader and purpose

This contract is for the implementer and reviewer of the first two migration
slices. After reading it, they can write the tests first, prove that the tests
fail against the current repository for the intended reason, and implement the
canaries without contacting a live backend or control plane.

The contract covers only:

- **S01:** prove one existing Terragrunt unit can inherit a canonical shared
  root without changing its state identity or generated configuration.
- **S02:** prove the official LiteLLM Terraform provider can represent one
  canary model through a new Terragrunt unit.

It does not authorize importing, planning against, or applying to live
resources.

## Global safety boundary

All contract tests must run with network access unavailable and with dummy
credentials. They must not decrypt sops files, load `.env`, read remote state,
query provider APIs, run imports, or mutate infrastructure.

The following commands are prohibited while satisfying this contract:

```text
terragrunt apply
terragrunt import
terragrunt plan
terragrunt run --all plan
tofu apply
tofu import
tofu plan
```

Provider installation is also outside the red/green loop. A cached provider may
be used later for an additional validation, but passing this contract must not
depend on registry or GitHub availability.

Generated files, caches, state, plan files, credentials, and secrets must not be
committed. Tests must use a temporary directory and remove it on exit.

## Test interface

The implementation must add one repository-local executable test entry point:

```text
tests/infra-ssot-contract.sh
```

It accepts exactly one selector, `s01`, `s02`, or `all`, exits non-zero on the
first failed invariant, and prints a short diagnostic naming the violated
invariant. It may use POSIX shell plus tools already supplied by the development
environment (`bash`, `jq`, `tofu`, and `terragrunt`). It must not use a network
mock that could silently fall through to a real endpoint.

Exact offline commands from the repository root:

```bash
env -i PATH="$PATH" HOME="$(mktemp -d)" \
  NO_PROXY='*' HTTPS_PROXY='http://127.0.0.1:9' HTTP_PROXY='http://127.0.0.1:9' \
  tests/infra-ssot-contract.sh s01

env -i PATH="$PATH" HOME="$(mktemp -d)" \
  NO_PROXY='*' HTTPS_PROXY='http://127.0.0.1:9' HTTP_PROXY='http://127.0.0.1:9' \
  tests/infra-ssot-contract.sh s02

env -i PATH="$PATH" HOME="$(mktemp -d)" \
  NO_PROXY='*' HTTPS_PROXY='http://127.0.0.1:9' HTTP_PROXY='http://127.0.0.1:9' \
  tests/infra-ssot-contract.sh all

tofu fmt -check -recursive
terragrunt hcl format --check
```

The test entry point itself must create and clean any finer-grained temporary
HOME or render directories it needs. The outer temporary HOME in the examples
is deliberately disposable.

## S01: shared-root canary

### Inputs

- One low-risk existing component and unit selected explicitly as the canary.
  The selection must not be inferred by scanning for the first unit.
- The canary's pre-migration component root, unit configuration, module source,
  generated provider block, generated encryption block, backend configuration,
  inputs, and computed backend key.
- A canonical shared-root helper under a clearly private/shared namespace.
- Dummy values supplied only by the test process for every environment lookup
  needed to render the canary.

The test must capture a normalized pre-migration fixture before the component
root is changed. The fixture contains configuration shape only: generated block
names and contents after normalization, module source, non-secret input keys,
backend settings, and backend key. It must contain no credential values or state
payload.

### Invariants

1. The canary component root delegates common backend and encryption behavior
   to exactly one canonical shared-root helper. It does not retain a copied
   implementation of those common blocks.
2. Provider-specific configuration remains component-owned. The shared helper
   does not contain provider-specific credentials, endpoints, source addresses,
   or generated provider bodies.
3. The rendered canary preserves the exact pre-migration backend key. A change
   in directory layout must not silently select a new state object.
4. All non-key backend settings are identical to the normalized pre-migration
   fixture.
5. The module source resolves to the same repository module as before.
6. Generated encryption semantics are identical: PBKDF2 key provider, AES-GCM
   method, and encrypted state and plan scopes remain present.
7. The state passphrase remains an injected sensitive input. It is never given
   a literal/default value and is absent from normalized test output.
8. The provider block and provider-specific input keys are unchanged for the
   canary.
9. Rendering requires no backend access, provider download, provider API, sops
   decryption, or real credential.
10. Other components are not migrated by S01. The test rejects incidental
    edits to their root ownership as part of this canary slice.

### Expected outputs

The S01 selector prints a compact success record containing:

```text
S01 PASS: shared root inherited; backend key stable; generated contract stable
```

The normalized post-migration render equals the committed pre-migration fixture
for every contract field except the expected include/delegation provenance.
No state or plan file exists after the test.

### Edge cases

- Missing dummy environment variables must fail with the variable name, not
  trigger loading a developer `.env`.
- Running from a subdirectory must either work by locating the repository root
  or fail clearly; it must not inspect a different parent `root.hcl`.
- Absolute working-tree paths and temporary paths must be normalized before
  comparison.
- Backend-key comparison must catch duplicate separators, `.`/`..`, renamed
  unit directories, and a component prefix derived from the wrong parent.
- A provider block moved into the shared helper must fail even if the final
  rendered provider text happens to match.
- A literal secret-looking value in generated HCL, fixture, or diagnostic
  output must fail the test.
- Stale `.terragrunt-cache` content must not affect the result.

### Red-fails-for-right-reason criterion

Before S01 implementation, run the S01 command and retain its output in the
slice evidence. It must fail because the selected component still owns a copied
backend/encryption implementation or because the canonical shared helper does
not exist. Acceptable diagnostic:

```text
S01 RED: canonical shared root missing or canary does not inherit it
```

A failure caused by absent credentials, MinIO/DNS/network access, provider
download, HCL syntax unrelated to the assertion, or a missing test dependency
is an invalid red. Fix the test harness, then rerun until it fails for the
contract reason.

## S02: LiteLLM provider canary

### Inputs

- A new LiteLLM component using the canonical component-first shape: a
  component root, a reusable model module, and one home-environment canary unit.
- The official `BerriAI/litellm` provider, pinned with an explicit compatible
  version constraint and lockable by the normal dependency-update workflow.
- One stable logical model alias used only as the canary. The exact alias and
  upstream model ID must be explicit inputs, not hard-coded inside resource
  logic.
- A LiteLLM API base URL and dedicated Terraform administrator credential
  referenced from environment input. Tests supply a syntactically valid dummy
  value; no live value is read.
- Model metadata inputs needed by the resource: provider/upstream identifier,
  context limit, output limit, input/output price, supported modalities,
  reasoning/tool capability, privacy tier, and lifecycle status.

The canary must not use the LiteLLM master key. Runtime provider credentials and
model API keys remain Vault values or environment references; they must not be
literal Terraform inputs.

### Invariants

1. Provider source is exactly `BerriAI/litellm`; its version is constrained and
   not `latest`, a branch, or an unpinned Git source.
2. LiteLLM provider configuration is generated or declared once for the
   component, not repeated in the model module.
3. Authentication uses a dedicated environment-injected Terraform admin key.
   No master key or token literal appears in tracked HCL, normalized fixtures,
   generated test output, or diagnostics.
4. The canary unit declares one logical alias mapped to one explicit upstream
   model. Resource addressing is stable and keyed by logical alias rather than
   list position.
5. Model metadata is typed and validated. Context/output sizes and prices are
   non-negative; output does not exceed context; modalities and privacy tier
   come from closed sets; lifecycle cannot silently default to production.
6. Provider/upstream secrets are represented only as environment references
   such as `os.environ/KEY_NAME`, never raw values.
7. The module exposes enough normalized output to compare alias, upstream ID,
   limits, prices, capabilities, privacy tier, and lifecycle without exposing a
   secret.
8. The canary is isolated in its own state key. Its key cannot collide with an
   existing component or unit.
9. The offline test validates HCL/module shape and input validation without
   initializing the remote backend or installing/calling the provider.
10. No existing LiteLLM YAML model route is removed or changed in S02. Canary
    proof precedes the later ownership cutover.

### Expected outputs

The S02 selector prints:

```text
S02 PASS: official provider pinned; canary model contract valid; no secret material
```

It also proves, using local static/render validation, that exactly one canary
alias would be addressed and that its normalized metadata matches the test
fixture. No provider request, state mutation, plan, or import occurs.

### Edge cases

- Missing admin-key input fails locally with a named validation error; it must
  not cause an HTTP request.
- A value named or shaped like a LiteLLM master key fails the secret-policy
  assertion even when placed in a fixture or comment intended as an example.
- Duplicate aliases, empty upstream IDs, zero/negative context, output greater
  than context, negative prices, unknown modalities, unknown privacy tiers, and
  implicit production lifecycle all fail locally.
- Metadata numeric values remain numbers through Terragrunt-to-OpenTofu
  serialization; stringified prices or limits fail.
- An embedding-only model cannot pass as a conversational canary.
- A provider source differing only by case or registry prefix fails; the source
  contract is exact.
- Cached `.terraform`, `.terragrunt-cache`, or lock data must not be required.

### Red-fails-for-right-reason criterion

Before S02 implementation, run the S02 command and retain its output in the
slice evidence. It must fail because the LiteLLM component/provider/module or
canary declaration does not yet exist. Acceptable diagnostic:

```text
S02 RED: LiteLLM Terraform canary contract not implemented
```

A registry lookup failure, proxy refusal, missing real admin key, live API
error, backend error, or provider schema error after attempted installation is
an invalid red: the test crossed the offline boundary. Rewrite it so absence of
the repository structure is the only initial failure.

## Green gate and evidence

S01 and S02 are independently green. S02 does not excuse a regression in S01.
For each slice, the implementation record must include:

1. The pre-implementation command and intended red diagnostic.
2. The minimal implementation diff.
3. The same command succeeding after implementation.
4. `tofu fmt -check -recursive` succeeding.
5. `terragrunt hcl format --check` succeeding.
6. `git status --short` proving no generated state, plan, cache, credential, or
   decrypted secret was added.

Live import, zero-diff plan, apply, or credential reminting require a later
human-approved cutover step. They are explicitly not evidence for this
contract.

## S03: catalog and dependency automation

S03 remains offline-testable. Renovate owns pinned provider, container, and
tool versions. A separate scheduled workflow refreshes a committed normalized
OpenCode Zen catalog and opens a review PR; it never promotes aliases or applies
infrastructure automatically.

The `s03` selector verifies:

1. Root Renovate configuration is valid JSON, uses the Terraform and Docker
   managers, and does not automerge infrastructure dependencies.
2. The catalog workflow supports both a schedule and manual dispatch, has only
   the repository permissions required to create its review PR, and invokes one
   repository-local updater.
3. The updater accepts an explicit local input fixture and output path. Offline
   fixture mode performs no HTTP request and emits deterministic, sorted JSON.
4. The normalized catalog records source ID, context/output limits, numeric
   input/output prices, modalities, reasoning/tools capabilities, privacy tier,
   lifecycle and source provenance without credentials. Wall-clock timestamps
   are excluded from normalized content so unchanged inputs remain byte-stable.
   Discovery records privacy as `unknown`; only human review may assign a more
   permissive tier. Free status is derived from both normalized prices being
   zero, never from provider membership or model naming.
5. Catalog discovery cannot modify Terragrunt aliases, run plan/apply/import,
   or enable automerge. Humans review catalog and alias changes separately.

Before implementation, `tests/infra-ssot-contract.sh s03` must fail only with:

```text
S03 RED: catalog and dependency automation not implemented
```

## S04: LiteLLM provider metadata and lifecycle boundary

S04 cannot claim green with upstream `BerriAI/litellm` v0.2.2: live canary
evidence showed no model importer and incomplete read-back/model metadata. A
replacement provider boundary must pass an offline conformance fixture before
any new live canary is authorized.

The `s04` selector requires:

1. The provider origin/version no longer resolves to the known-incomplete
   upstream v0.2.2 boundary. Implicit and explicit Terraform Registry
   hostnames are normalized before comparison.
2. The model resource has an importer keyed by stable LiteLLM model ID.
3. `team_id` remains an optional, future-compatible model input and is
   persisted/read back when set. LiteLLM OSS model administration cannot use
   team-scoped ownership; the current canary leaves it empty and uses a
   proxy-admin bootstrap credential. Team ownership is Enterprise-only.
4. Context/output limits, modalities, and reasoning/tools are persisted as
   actual LiteLLM `model_info` only where the API supports them. Privacy tier
   and lifecycle remain local governance/catalog metadata and are never sent
   to LiteLLM.
5. The offline gate inspects the actual pinned provider fork submodule and runs
   its checksum-locked Go unit tests. Tests cover importer schema, typed fields, API
   request serialization, read-back flattening, and create/read/import
   zero-diff behavior. A capability manifest or fixture-copying script cannot
   satisfy this gate.

Before implementation, `tests/infra-ssot-contract.sh s04` must fail with:

```text
S04 RED: LiteLLM provider importer/metadata/read-back boundary not implemented
```

## S08: Vault runtime-secret canary

S08 closes only when all of these are evidenced:

1. A scoped LiteLLM provider resource mints the canary credential.
2. The OpenBao write uses an ephemeral input and `data_json_wo`; sanitized
   target-state inspection proves the copied value is absent.
3. One workload consumes only the Vault Agent render, with least-privilege file
   mode and a successful value-free runtime probe.
4. The live KV mount, read policy, and AppRole are imported into the OpenBao
   component before Terraform may claim ownership. The import plan must be
   zero-create, zero-destroy and preserve every existing policy attached to the
   shared `vault-agent` role.

Passing the first three checks is partial progress, not S08 completion.
