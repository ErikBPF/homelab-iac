# Infrastructure SSOT hard-cutover implementation plan

**Status:** In progress — S01–S04 complete; S05 implementation and plan green, production cutover pending

## Outcome

`homelab-iac` becomes the fleet-wide source of truth for infrastructure resources. Terragrunt drives OpenTofu; Vault holds runtime secret values; sops holds bootstrap/root-of-trust values. Every component cutover is plan-gated, recoverable, and followed by health verification plus backup.

## Non-negotiable contracts

- One encrypted state key per Terragrunt unit; existing state keys do not drift accidentally.
- No live plan/import/apply until offline RED tests fail for the intended behavior and the smallest implementation makes them green.
- Terraform owns Vault structure/policy, never runtime secret values.
- Runtime secrets migrate to Vault; host/build/bootstrap secrets remain sops.
- Production applies are manual; network applies require wired LAN.
- Production chaos requires explicit per-run approval and automatic rollback.
- OpenBao/OpenTofu targets: 6h RPO, 4h RTO, weekly integrity checks, quarterly isolated restore, annual full recovery exercise.

## Provider constraint discovered during planning

Official `BerriAI/litellm` v0.2.2 must pass a canary against LiteLLM 1.91.2. It cannot currently represent all existing `model_info` fields, including several capability, probe, TTS, and token-limit fields. Production models remain YAML-owned until metadata parity is proven or provider support is extended. A hard cutover that silently drops metadata is forbidden.

## TDD loop per slice

1. Preserve the human seed in `docs/behaviors/infra-ssot-hard-cutover/behavior.md`.
2. Refine `test-contract.md`; implementation cannot rewrite it silently.
3. Agent writes offline RED tests and demonstrates correct failure.
4. Separate implementation agent writes minimum GREEN change.
5. Run Bats, Terragrunt validation, formatting, lint, and secret checks.
6. Human reviews any live plan/import/apply.
7. Verify runtime health, trigger backup, record evidence.

## Slices

- [x] **S01: Shared Terragrunt-root canary** `risk:high` `depends:[]`
  > One low-risk unit uses a canonical shared root while all 25 existing state keys remain byte-for-byte stable.
- [x] **S02: LiteLLM provider canary** `risk:high` `depends:[]`
  > A disposable Gemma alias proves create/read/update/import/delete, zero-diff second plan, environment-key references, and LiteLLM 1.91.2 compatibility.
- [x] **S03: Catalog and dependency automation** `risk:medium` `depends:[]`
  > Renovate updates providers/images/tools; a scheduled workflow opens review PRs for normalized Zen catalog/pricing changes.
- [x] **S04: Close LiteLLM provider metadata gap** `risk:high` `depends:[S02]`
  > Provider or local module represents every production `model_info` invariant with contract tests; otherwise YAML remains authoritative.
- [ ] **S05: Terraform-manage LiteLLM models** `risk:high` `depends:[S03,S04]` `HITL`
  > Stable aliases and reviewed free/manual routes are provider-owned; legacy aliases are removed and allowlists reminted.
- [ ] **S06: Terraform-manage LiteLLM control plane** `risk:high` `depends:[S02]` `HITL`
  > Teams, embedded budgets, credentials, policies, and reminted keys are declarative; a scoped Terraform admin key remains bootstrap sops.
- [ ] **S07: Finish OpenCode routing** `risk:medium` `depends:[S05,S06]`
  > New sessions start on LiteLLM GLM; Architect reviews with GLM; General/Explore implement, debug, and explore with MiMo.
- [ ] **S08: Vault runtime-secret canary** `risk:high` `depends:[S01]` `HITL`
  > One workload consumes an operator-reminted Vault value through Terraform-owned mount/policy/auth wiring with no value in state.
- [ ] **S09: Discovery runtime-secret cutover** `risk:high` `depends:[S08]` `HITL`
  > Discovery dotenv/sops sources retain config/bootstrap only; runtime stacks consume Vault Agent renders.
- [ ] **S10: Remaining compose/host secret cutovers** `risk:high` `depends:[S08]` `HITL`
  > Kepler, Orion, Voyager, OpenCode, Hermes, and NetBird runtime credentials are Vault-sourced; ignored plaintext work copies are eliminated.
- [ ] **S11: SOPS and secret hygiene gates** `risk:medium` `depends:[S09,S10]`
  > CI rejects plaintext/tracking errors; weekly trusted-host decrypt checks and quarterly two-copy escrow drills alert on failure.
- [ ] **S12: Backup and DR hardening** `risk:high` `depends:[S01,S08]`
  > Post-apply backups, 6h snapshots, weekly integrity checks, quarterly isolated restores, and the 4h recovery runbook are evidenced.
- [ ] **S13: Bounded chaos harnesses** `risk:medium` `depends:[S12]`
  > Chaos Mesh covers disposable k8s, Toxiproxy covers isolated dependencies, and confirmed recipes test production recovery paths safely.
- [ ] **S14: Canonical network-component cutovers** `risk:high` `depends:[S01,S12]` `HITL`
  > UniFi, Tailscale, Cloudflare, AdGuard, NetBird, and PocketID reach zero-diff from standardized component units.
- [ ] **S15: Remaining infrastructure cutovers** `risk:medium` `depends:[S01,S12]` `HITL`
  > GitHub, Oracle, Vault, and other stable-provider resources use canonical units and independent state.
- [ ] **S16: Full recovery exercise** `risk:high` `depends:[S05,S06,S09,S10,S11,S12,S13,S14,S15]` `HITL`
  > An isolated rebuild reconstructs state, Vault, LiteLLM, secrets, and OpenCode routing within RPO/RTO.

## Live canary evidence

- 2026-07-12: LiteLLM 1.91.2 create, read/refresh, update, restore, delete, and zero-diff plans passed with provider v0.2.2.
- A route-scoped `key_type = "management"` key remained `internal_user` and correctly failed model creation with HTTP 403. The successful canary used a temporary `proxy_admin` identity, deleted after each run.
- Import failed with `resource litellm_model doesn't support import`. The orphaned disposable model was deleted through `/model/delete`; both the remote model count and canary state count were verified as zero.
- 2026-07-13: fork commits `9ba3490` and `715b7e4` passed provider CI and the full LiteLLM 1.91.2 lifecycle: create, stable DB-backed read, update, restore, import, one expected unreadable credential-reference reconciliation, zero-diff, and delete. Cleanup verified zero canary models, keys, and state resources.
- 2026-07-13: fork v1.0.1 was released from commit `594439b3b3ad3c407b2035f079c49e20fda8fed4`. The Linux amd64 artifact checksum is pinned and its detached checksum signature verified with RSA-4096 key `817A482B5313F28EC8E12613B025710D7A6FBE7F`. Normal provider installation remains blocked until the user completes GitHub OAuth publication in the Terraform Registry web UI.
- 2026-07-13: Terraform Registry publication completed. OpenTofu installed `registry.terraform.io/ErikBPF/litellm` v1.0.1 with developer signature key ID `B025710D7A6FBE7F`; the registered provider passed create, read, update, restore, import/reconcile, repeated zero-diff, and delete against LiteLLM 1.91.2. The harness minted and revoked its own 15-minute proxy-admin identity; independent cleanup found zero canary models, users, keys, and state resources.
- 2026-07-13: post-registration production inventory found typed parity gaps for vision, character-priced TTS, mode-specific optional limits, and probe metadata embedded in YAML. This kept S04 open until the v1.1 provider work below closed them.
- 2026-07-13: fork v1.1.0 added typed vision, character-pricing, voice, probe, and legacy token metadata. Its first registered canary exposed a perpetual-diff defect when LiteLLM populated `max_tokens = 204800` for an omitted field. RED regression coverage reproduced it; v1.1.1 made those API-populated fields Optional+Computed while preserving explicit false/zero values.
- 2026-07-13: signed fork v1.1.1 from commit `19158c1f277643f6d69421aef320f85ad9c52016` passed provider CI, checksum/signature verification, Registry installation, and the full LiteLLM 1.91.2 create/read/update/restore/import/reconcile/zero-diff/delete lifecycle. Eventual cleanup converged to zero canary models, users, keys, and state resources.
- 2026-07-13: the production model unit validates all 16 Discovery aliases, preserves typed voice/vision/probe/mode metadata, and pins reviewed Zen context/output/pricing. A read-only plan is exactly `16 to add, 0 to change, 0 to destroy`; `yaml_model_list_cutoff` remains false and no production apply/import/YAML edit occurred.
- 2026-07-14: Kepler's disposable AI-serving stack was retired at its workload and host owners. The pending S05 declaration now contains exactly nine non-Kepler aliases; `bge-m3`, `bge-reranker-v2-m3`, `tts-pt-br`, `tts-pt-br-piper`, and `whisper-pt-br` are absent from the production manifest and consumer allowlists. Offline contract tests reject their return and any Kepler model endpoint. No plan, import, apply, or live LiteLLM mutation occurred; S05 remains HITL-gated.
- LiteLLM OSS rejects team-owned model administration as Enterprise-only. A dedicated sops-held proxy-admin bootstrap credential is therefore required for Terraform; generated management keys remain insufficient. Production migration remains maintenance-gated until the reviewed DB-model/YAML cutoff sequence is executed.
- 2026-07-12: S03 seeded the normalized OpenCode Zen catalog from models.dev (79 models: 6 active free, 24 deprecated). Renovate and the scheduled catalog workflow are review-only and cannot plan/apply/import infrastructure.
- 2026-07-13: the AdGuard filtering canary initialized through the canonical shared Terragrunt root and returned `No changes`; the preserved state-key and rendered-contract checks also passed.

## Initial verification commands

```bash
bats --tap tests/shared-root.bats
terragrunt hcl validate
tofu fmt -recursive -check
terragrunt hcl format --check --diff
tflint --recursive
```

Live commands are intentionally absent from the RED phase.
