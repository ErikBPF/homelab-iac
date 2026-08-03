# Proposal index and risk/value matrix

Last synchronized: 2026-08-02.

This is the portfolio view for every local record under [`proposals/`](proposals/).
The proposal status headers remain authoritative for execution detail. This
index exposes stale headers, competing scopes, and the next portfolio action.

Any proposal creation, edit, rename, graduation, or deletion must update this
index in the same change. Recheck the affected status, remaining value,
delivery risk, next gate, and file coverage.

## Scale

- **Value:** remaining benefit, not value already delivered.
- **Risk:** risk of executing the remaining work, not risk of editing the doc.
- **High:** fleet security, state, identity, networking, or repeated operations.
- **Medium:** bounded operational or workflow benefit/change.
- **Low:** speculative work, cleanup, or document closure.

## Open and attention-required records

“Attention-required” includes blocked work, trigger-based backlog, and stale
open headers that should be graduated or retired.

| Proposal | Current status | Remaining value | Delivery risk | Next gate | File coverage |
|---|---|---:|---:|---|---|
| [Home network and router security segmentation](proposals/2026-08-01-network-router-security-segmentation.md) | Proposed after live sweep; P0 containment not started | High | High | Capture an authenticated UniFi inventory, identify `192.168.1.2`, then close host-trust gaps before VLAN canaries. | `homelab-iac` UniFi/Tailscale, `desktop-nixos` host firewalls, `servarr` exposed workloads |
| [Stateful stack and release hardening](proposals/2026-07-13-stateful-stack-release-hardening.md) · [execution plan](proposals/2026-07-13-stateful-stack-release-hardening-execution-plan.md) | In progress; P7 active | High | High | Continue one service or coupled database group per verified backup/restore slice. | `servarr/machines/discovery`, `desktop-nixos` compose orchestration |
| [Runtime security monitoring](proposals/2026-07-25-runtime-security-monitoring.md) | Observe-only rollout in progress | High | Medium | Finish baseline/force-fire gates, then assign non-overlapping alert ownership with Wazuh. | `runtime-security-inventory.json`, `desktop-nixos` journals, `servarr` Loki/Grafana rules |
| [Fleet Wazuh SIEM integration](proposals/2026-07-26-fleet-wazuh-siem-integration.md) | In progress on Kepler; CEF delivery plus encrypted local/offsite snapshot restore proven | High | High | Set measured alert/raw retention and split API/indexer credentials before one canary agent. | `servarr` security stack, `desktop-nixos` Kepler firewall/diagnostics, UniFi CyberSecure/syslog |
| [Fleet upgrade hardening](proposals/2026-07-12-fleet-upgrade-hardening.md) | Partially implemented | High | High | Decide R3 automation boundary before adding sequential activation and post-switch verification. | `desktop-nixos` upgrade recipes, fleet metadata, deploy-rs |
| [NetBird overlay](proposals/2026-07-10-netbird-selfhosted-overlay.md) | Partially live; control plane and public relay pair are source-managed | High | Medium | Enroll one genuinely off-LAN peer and verify overlay plus relay traversal; dashboard passkey remains upstream-blocked. | `desktop-nixos` clients/control plane/relays, `homelab-iac` policy/Oracle/DNS, `servarr` runtime |
| [Gemini persistent code stack](proposals/2026-07-23-gemini-persistent-code-stack.md) | Proposed | High | Medium | Run the Herdr compatibility probe; keep one remote primary and no pane-history persistence. | `desktop-nixos` Gemini/Herdr modules and user configuration |
| [Fleet container placement and SRP](proposals/2026-07-11-fleet-container-placement-srp.md) | Proposed; live placement needs re-audit | Medium | High | Approve placement and PocketID decisions before moving workloads. | `servarr` compose stacks, `desktop-nixos` orchestration, `homelab-gitops` workloads |
| [Home Assistant and AI](proposals/2026-07-02-home-assistant-ai-consolidation.md) | Decision gates open; manifest-v2 harness merged, deployment still gated | Medium | High | Select at most two extensions and an approved runtime/capacity path before shadow deployment. | `ha-harness`, `home-assistant-config`, `homelab-iac` LiteLLM routes |
| [Hermes deferred improvements](proposals/2026-06-29-hermes-deferred-improvements.md) | Trigger-based backlog | Medium | High | Require sandboxing before wider reach; take quality work only after measurement. | `hermes-flake`, `hermes-skills`, `servarr` Hermes runtime |
| [Telstar Oracle ARM host](proposals/2026-07-01-telstar-oracle-arm-host.md) | Ready; blocked on A1 capacity | Medium | High | Wait under one acquisition owner; PAYG or public ingress needs a separate decision. | `desktop-nixos` Telstar host, `homelab-iac` Oracle resources |
| [Fleet backlog and decision gates](proposals/2026-07-02-open-decisions-and-work.md) | Active coordination tracker | Medium | Medium | Keep it as next-gate authority; do not duplicate child plans. | All proposal records and cross-repository gates |

## Closed and historical local records

The thematic archive remains [`completed-proposals.md`](completed-proposals.md).
These entries ensure every local proposal file is indexed.

| Proposal | Current status | Remaining value | Delivery risk | Next gate | File coverage |
|---|---|---:|---:|---|---|
| [Hermes agentmemory integration](proposals/2026-06-25-hermes-agentmemory-integration.md) | Deferred; superseded by native wiki | Low | Low | Reopen only for a measured recall failure. | Historical Hermes/agentmemory integration record |
| [Hermes deferred plans](proposals/2026-06-25-hermes-deferred-plans.md) | Superseded by consolidated Hermes backlog | Low | Low | Retain as historical link target. | Historical Hermes plan |
| [Fleet ESP enlargement](proposals/2026-07-12-fleet-esp-enlargement.md) | Implemented | Low | Low | Reopen only on measured ESP pressure. | `desktop-nixos` host disk layouts |
| [Discovery ESP migration](proposals/2026-07-14-discovery-esp-migration.md) | Implemented with restore/reboot evidence | Low | Low | Retain recovery evidence. | `desktop-nixos` Discovery install/restore paths |
| [Fleet CI Discord notifications](proposals/2026-07-24-fleet-ci-discord-notifications.md) | Implemented and active | Low | Low | Review usefulness after observation window. | Fleet GitHub CI workflows and Discord secrets |
| [Fleet security notifications](proposals/2026-07-24-fleet-security-notifications.md) | Implemented; Cleytin-only mention contract active | Medium | Low | Review usefulness and duplicates after 30 days. | Fleet security workflows and `tests/security-notification-contract.sh` |
| [Fleet flake package-updater CI hardening](proposals/2026-07-31-flake-package-updater-ci-hardening.md) | Implemented and closed | Low | Low | Reopen only if App-authenticated package updates stop reaching normal PR CI. | `renovate-config`, `hermes-flake`, `opencode-flake`, `codex-flake` |
| [Observability continuation](proposals/2026-07-03-observability-continuation.md) · [execution plan](proposals/2026-07-03-observability-continuation-execution-plan.md) | Implemented and closed | Low | Low | Reopen only when a documented trigger gate has a concrete consumer or failure. | `servarr` Grafana/Prometheus, `desktop-nixos` telemetry, proposal execution plan |
| [Deferred repository hygiene](proposals/2026-07-17-deferred-repository-hygiene.md) | Completed | Low | Low | Reopen only when a fleet audit finds concrete dirty, stale, or unmerged work. | `repos.json`, local worktrees, inventoried GitHub branches/PRs |
| [Cleytin N0 responder](proposals/2026-07-21-hermes-argus-n0-responder.md) | Implemented; all Grafana firing alerts route through authenticated Cleytin analysis | Low | Low | Review volume and duplicates after the observation window; keep Scrutiny/Uptime Kuma exceptions explicit. | `desktop-nixos`, `servarr`, Grafana, Discord webhook routes |
| [Repository structure improvements](proposals/2026-06-24-repo-structure-improvements.md) | Graduated; Phase 0 delivered | Low | Low | Reopen only for measured structural friction. | Coordination layout and component ownership docs |
| [Source-backed host improvements](proposals/2026-06-24-source-backed-host-improvements.md) | Graduated; useful slices moved to backlog | Low | Low | Follow H1–H5 in the fleet backlog. | `desktop-nixos` host-source records |
| [Impermanence / ephemeral root](proposals/2026-07-03-impermanence-ephemeral-root.md) | Evaluated and retired | Low | Low | Reopen only for an evidence-backed host problem and safe canary. | Historical NixOS root-state evaluation |
| [OpenCode LiteLLM routing](proposals/2026-07-12-opencode-litellm-routing.md) | Implemented; DeepSeek live on Endeavour and Discovery | Low | Low | Activate the source-ready Pathfinder generation when the host returns online. | `homelab-iac` model routes, `desktop-nixos` OpenCode/Hermes consumers, `servarr` validation contract |
| [Free-tier cloud resources](proposals/2026-07-02-free-tier-cloud-resources.md) | Evaluated and graduated | Low | Low | Existing B2/Vanguard controls remain sufficient. | B2 backup and Vanguard monitoring records |
