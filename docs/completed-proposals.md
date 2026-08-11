# Completed proposals by theme

Canonical index for implemented, executed, superseded, or evaluated-and-dropped
proposal records. Cross-repository decisions live in `homelab`; host and
component implementation records remain in `desktop-nixos`.

## Governance, ownership, and delivery

- [Repository ownership, SSOT, and SRP](decisions/2026-06-29-repo-ssot-srp.md)
- [Fleet-wide Renovate](decisions/2026-07-11-fleet-renovate-consolidation.md)
- [Repository structure improvements](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-24-repo-structure-improvements.md)
- [Source-backed host improvements](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-24-source-backed-host-improvements.md)
- [Documentation reorganization and install guide](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-26-docs-reorg-and-install.md)
- [Session landing plan](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-session-landing-plan.md)
- [deploy-rs as the fleet deployment standard](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-30-deploy-rs-as-deploy-standard.md)
- [Instruction file consolidation](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-12-instruction-file-consolidation.md)
- [TokenSave evaluation and rejection](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-02-tokensave-dataplatform-eval.md)
- [Fleet CI Discord notifications](proposals/2026-07-24-fleet-ci-discord-notifications.md)
- [Fleet security notifications](proposals/2026-07-24-fleet-security-notifications.md)

## Secrets, backup, and disaster recovery

- [Vault runtime secrets platform](decisions/2026-06-29-vault-secrets-platform.md)
- [Offsite disaster-recovery anchor](decisions/2026-06-30-offsite-dr-crown-jewels.md)
- [Vault backup and restore proof](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-vault-backup-plan.md)
- [OpenBao root-token recovery](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-30-openbao-root-recovery.md)
- [Voyager Oracle offsite host](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-voyager-oracle-offsite-host.md)
- [Vanguard second Oracle node](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-10-vanguard-second-oracle-node.md)

## Network, identity, and external control planes

- [Declarative UniFi configuration](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-20-unifi-declarative-config.md)
- [Cloudflare token Terraform migration](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-28-cloudflare-token-terraform-migration.md)
- [Free-tier cloud resources evaluation](proposals/2026-07-02-free-tier-cloud-resources.md)

## Hosts, hardware, storage, and developer substrate

- [Archinaut printer host](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-16-printer-nixos-host.md)
- [Archinaut kernel-direct boot](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-20-archinaut-kernel-direct-boot.md)
- [Archinaut SD recovery hardening](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-10-archinaut-sd-recovery-hardening.md)
- [Orion disk reorganization](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-10-orion-disk-reorg.md)
- [Discovery resilience fixes](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-discovery-resilience-fixes.md)
- [Fleet ESP enlargement](proposals/2026-07-12-fleet-esp-enlargement.md)
- [Discovery ESP migration](proposals/2026-07-14-discovery-esp-migration.md)
- [Impermanence / ephemeral root evaluation](proposals/2026-07-03-impermanence-ephemeral-root.md)
- [Orion development sandbox and container pivot](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-10-orion-dev-sandbox-microvm.md)
- [Shared sccache compiler cache](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-30-sccache-shared-cache.md)

## Kubernetes, registries, and workload platforms

- [Kepler k3s MicroVM cluster](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-19-kepler-k3s-microvm-cluster.md)
- [Homelab GitOps platform](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-20-cluster-homelab-gitops.md)
- [Declarative Harbor](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-22-harbor-declarative.md)
- [Harbor pull-through mirror](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-22-harbor-pullthrough-mirror.md)

## Observability foundations and operational resilience

These closed records cover shipped foundation scopes. Remaining observability
work stays in the
[active continuation proposal](proposals/2026-07-03-observability-continuation.md).

- [Telemetry hardening](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-20-telemetry-hardening.md)
- [Grafana fleet monitoring](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-grafana-fleet-monitoring.md)

## Home automation, AI, and agent tooling

- [Declarative Home Assistant](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-05-23-home-assistant-declarative.md)
- [Home Assistant voice assistant](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-05-27-home-assistant-voice-assistant.md)
- [Hermes memory, SOUL, and skills](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-24-hermes-memory-skills.md)
- [Hermes native LLM wiki](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-26-hermes-native-llm-wiki.md)
- [Hermes flake update hardening](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-30-hermes-flake-update-hardening.md)
- [Cleytin N0 responder](proposals/2026-07-21-hermes-argus-n0-responder.md)
- [Codex flake](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-codex-flake.md)
- [Codex flake update strategy](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-30-codex-flake-update-strategy.md)
- [OpenCode improvements](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-opencode-improvements.md)
- [OpenCode flake](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-01-opencode-flake.md)
- [OpenCode Zen account pooling](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-11-opencode-zen-account-pooling.md)
- [OpenCode LiteLLM routing](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-12-opencode-litellm-routing.md)
- [Terminal tooling additions](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-10-terminal-tooling-additions.md)
