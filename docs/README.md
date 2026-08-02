# Homelab architecture

This directory records cross-repository state. Component runbooks and
implementation details stay in their owning repositories.

## Ownership

- Cross-repository decisions, proposals, audits, and rollout status are
  canonical here.
- Host implementation and hardware reference belong to `desktop-nixos`.
- Network and external control-plane implementation belongs to `homelab-iac`.
- Workload implementation belongs to `servarr` or `homelab-gitops`.
- Runtime secret values belong to Vault; bootstrap and host/build secrets
  belong to sops.

Some pre-migration proposal names still have divergent full copies in
`desktop-nixos`. Reconcile newer evidence into the canonical record here before
replacing those component copies with relocation stubs; neither copy should be
blindly overwritten.

## Implemented decisions

- [All completed proposals grouped by theme](completed-proposals.md)
- [Repository ownership, SSOT, and SRP](decisions/2026-06-29-repo-ssot-srp.md)
- [Vault runtime secrets platform](decisions/2026-06-29-vault-secrets-platform.md)
- [Offsite disaster-recovery anchor](decisions/2026-06-30-offsite-dr-crown-jewels.md)
- [Fleet-wide Renovate](decisions/2026-07-11-fleet-renovate-consolidation.md)

## Current records

- [Proposal index and risk/value matrix](proposal-index.md)
- [Fleet backlog and decision gates](proposals/2026-07-02-open-decisions-and-work.md)
- [Stateful stack release hardening](proposals/2026-07-13-stateful-stack-release-hardening-execution-plan.md)
- [Fleet upgrade hardening](proposals/2026-07-12-fleet-upgrade-hardening.md)
- [Observability continuation](proposals/2026-07-03-observability-continuation.md)
- [NetBird overlay](proposals/2026-07-10-netbird-selfhosted-overlay.md)
- [Telstar Oracle ARM host](proposals/2026-07-01-telstar-oracle-arm-host.md)
- [Hermes Cleytin N0 responder](proposals/2026-07-21-hermes-argus-n0-responder.md)
- [Runtime security monitoring](proposals/2026-07-25-runtime-security-monitoring.md)
- [Fleet Wazuh SIEM integration](proposals/2026-07-26-fleet-wazuh-siem-integration.md)
- [Gemini persistent code stack](proposals/2026-07-23-gemini-persistent-code-stack.md)

Runtime security inventory: [`runtime-security-inventory.json`](runtime-security-inventory.json).

[`proposals/`](proposals/) also contains deferred and historical plans.
Directory placement preserves links; each document's status header is
authoritative.

## Migration

The proposals and ecosystem decisions here moved from `desktop-nixos` starting
at source revision `8809e30adc71c941528a430cbf50f644ec21e7c7`. Their former
paths contain relocation stubs so existing links remain useful. Host-specific
as-built records and runbooks remain in `desktop-nixos`.
