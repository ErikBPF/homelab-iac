# Backlog da frota — decisões e execução por cluster

**Date:** 2026-07-02
**Status:** Backlog ativo — reagrupado e reavaliado em 2026-07-15
**Regra:** cada concern tem um doc-fonte. Este arquivo decide prioridade e aponta
o próximo gate; não duplica planos detalhados. IDs antigos permanecem para não
quebrar referências históricas.

---

## Avaliação dos RFCs ativos

| RFC | Disposição | Motivo / próximo passo |
|-----|------------|------------------------|
| `repo-structure-improvements` | **Graduar: Phase 0 implementada** | Contrato + `structure-check` entregues; refactor amplo recusado. `_flake/` conflita com o skip de segmentos `_` do `import-tree`. |
| `source-backed-host-improvements` | **Graduar P0/P1; extrair cauda** | Exposição, deploy-rs e inventário entregues. Restam decisões concretas H1–H4 abaixo, não um programa aberto de melhorias. |
| `hermes-agentmemory-integration` | **Retirar como plano ativo; preservar como referência de HAI6** | Wiki nativa substituiu agentmemory. Reabrir só se busca semântica provar necessidade. |
| `hermes-deferred-plans` | **Apagar após corrigir links** | Supersedido integralmente pelo backlog consolidado de Hermes. |
| `hermes-deferred-improvements` | **Manter** | Dono único da cauda Hermes. |
| `telstar-oracle-arm-host` | **Manter bloqueado** | Implementação pronta; serviço de captura aguarda capacidade A1. |
| `free-tier-cloud-resources` | **Retirar RFC amplo; extrair C3–C5** | Catálogo mistura oportunidades sem demanda. Só decisões com benefício identificado sobrevivem. |
| `home-assistant-ai-consolidation` | **Manter** | Shadow stack implementado, capacity/deploy gates ainda abertos. |
| `tokensave-dataplatform-eval` | **Graduado: avaliado e removido** | Self-benchmark forte, mas sem A/B independente; 81 tools + índices stale falharam o contrato. |
| `impermanence-ephemeral-root` | **Retirar** | Sem problema concreto, inventário de persistência ou host-canário. Reabrir após H4, não antes. |
| `observability-continuation` | **Manter** | Dono do cluster O1–O5. |
| `netbird-selfhosted-overlay` | **Manter** | Parcialmente live; rollout e hardening restantes. |
| `fleet-container-placement-srp` | **Manter para N3/N4** | Regra proposta; separações ainda precisam decisão explícita. |
| `fleet-esp-enlargement` | **Manter até R1; depois graduar** | Três hosts concluídos; Discovery é o último gate e tem plano próprio. |
| `fleet-upgrade-hardening` | **Manter** | Contrato parcialmente entregue; orquestração e projeção ESP abertas. |
| `opencode-litellm-routing` | **Graduar** | Roteamento, aliases, chave virtual e agents já estão declarados no laptop. |
| `stateful-stack-release-hardening` + execution plan | **Manter ambos** | RFC fixa decisões; execution plan controla gates operacionais. Não são duplicados. |
| `discovery-esp-migration` | **Manter bloqueado por aprovação** | Plano destrutivo correto: ensaios/evidência antes da janela. |

---

## Cluster R — recovery, estado e upgrades

Decisões que podem destruir estado ou mudar política de ativação. Ordem:
evidência → aprovação → execução.

| ID | Decisão / trabalho | Dono | Próximo gate |
|----|--------------------|------|--------------|
| R1 | **Discovery ESP: autorizar ou não a migração destrutiva** | [`discovery-esp-migration`](2026-07-14-discovery-esp-migration.md) | Completar D1–D4, apresentar manifest de evidência <24h; só então pedir aprovação da janela D5. |
| R2 | **Stateful P1: autorizar adoção in-place do SWAG** | [`stateful-stack-release-hardening-execution-plan`](2026-07-13-stateful-stack-release-hardening-execution-plan.md) | Inventário/backups/pins verdes + approval manifest exato; P1 continua frozen até aprovação. |
| R3 | **Orquestração de upgrade: até onde automatizar** | [`fleet-upgrade-hardening`](2026-07-12-fleet-upgrade-hardening.md) | Escolher build-only, staged activation ou rollout automático por classe de host; preservar stop rules. |
| B2 | **Primeiro drill trimestral de restore OpenBao** | [`vault-disaster-recovery`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/vault-disaster-recovery.md) | Janela própria; registrar snapshot, restore isolado e resultado. |
| B3 | **Drill destrutivo do runbook etcd** | [`kepler-k3s-microvm-cluster`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-19-kepler-k3s-microvm-cluster.md) §15 | Janela própria no Kepler; não acoplar a deploy comum. |
| B4 | **Escrow físico restante** | [`vault-secrets-platform`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-vault-secrets-platform.md) | Cópia offline da passphrase fora de casa + age key break-glass fora da frota. |

## Cluster N — rede, edge, cloud e placement

| ID | Decisão / trabalho | Dono | Próximo gate |
|----|--------------------|------|--------------|
| A2 | **Manter `k8s-apiserver` no stack networking do Discovery?** | [`discovery-resilience-fixes`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-discovery-resilience-fixes.md) | Padronizar `--project-name` ou remover stack; não aceitar drift recorrente. |
| A3 | **Resolver self-dependency DNS do Discovery** | mesmo doc | Definir resolver do host independente do AdGuard local. |
| N1 | **NetBird: escopo final do rollout e convivência com Tailscale** | [`netbird-selfhosted-overlay`](2026-07-10-netbird-selfhosted-overlay.md) | Definir hosts a migrar, período dual-overlay e critério de retirada; completar hardening/IaC restante. |
| N2 | **Telstar: PAYG para furar capacity pool ou continuar esperando** | [`telstar-oracle-arm-host`](2026-07-01-telstar-oracle-arm-host.md) | Default: esperar serviço de captura. PAYG exige decisão explícita de gasto. |
| N3 | **Adotar regra de placement proposta** | [`fleet-container-placement-srp`](2026-07-11-fleet-container-placement-srp.md) | Aprovar regra por propósito/runtime antes de mover qualquer workload. |
| N4 | **Separar PocketID e quais outros serviços** | mesmo doc | Decidir PocketID primeiro; secondary separations somente por benefício isolado. |
| C3 | **Adicionar mirror externo de monitoramento** | [`free-tier-cloud-resources`](2026-07-02-free-tier-cloud-resources.md) | Escolher Grafana Cloud ou probe outside-in mínimo; sem duplicar observabilidade inteira. |
| C4 | **Object storage offsite: OCI, R2 ou B2** | mesmo doc | Só escolher após definir dataset, tamanho, retenção e restore test. |
| C5 | **Permitir inferência/embeddings cloud com dados privados?** | mesmo doc | Default: não. Exceção exige classificação dos dados e rota degradada explícita. |
| B9 | **Provisionar Telstar quando A1 liberar** | Telstar RFC | IP → `fleet-json` → deploy → switch → verificação → graduar. |
| B10 | **Root-cause da instabilidade do Discovery** | discovery resilience | Próximo evento: correlacionar journal persistente, `net-watch` e sysstat. |
| B12 | **IaC: importar reserva HA `.115` e remover reservas velhas** | [`repo-ssot-srp`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-repo-ssot-srp.md) | Host cabeado; revisar saved plan antes do apply. |

## Cluster H — arquitetura e hardening dos hosts

| ID | Decisão / trabalho | Dono | Próximo gate |
|----|--------------------|------|--------------|
| A4 | ~~**Fases 1–5 do repo-structure**~~ | **Resolvido 2026-07-15:** aceitar árvore atual; graduar Phase 0 | Encerrado. Splits futuros só quando trabalho real expuser boundary. |
| A5 / H1 | **Apertar sudo nos servers agora?** | [`source-backed-host-improvements`](2026-06-24-source-backed-host-improvements.md) | Auditar comandos realmente usados por deploy-rs/ops; propor regras específicas antes de remover passwordless wheel. |
| H2 | **Narrow NFS `no_root_squash` no Kepler** | mesmo doc | Inventariar clientes/CSI paths; separar exports; dry + mount/chown tests. |
| H3 | **Qual serviço customizado sandboxar primeiro** | mesmo doc | Rank por blast radius; um unit por slice com `systemd-analyze security` antes/depois. |
| H4 | **Inventário de estado por host** | mesmo doc | Fazer inventário sem mudar mount topology. Só evidência de drift recorrente pode reabrir impermanence. |
| H5 | **Acceptance checks de host que valem CI** | mesmo doc | Escolher contratos estáveis: SSH, firewall, secrets existentes e critical units. |

## Cluster O — cluster k3s e observabilidade

| ID | Decisão / trabalho | Dono | Próximo gate |
|----|--------------------|------|--------------|
| O0 / S0 | **Bootstrap reproduzível do Argo + ESO** | [`kepler-k3s-platform-status`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/reference/kepler-k3s-platform-status.md) | P0: credencial read-only dedicada do repo + `vault-approle` sob sops; provar rebuild sem segredo manual/pessoal. |
| A7 | **Harbor pull-through: Job declarativo ou reconciler atual** | [`harbor-pullthrough-mirror`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-22-harbor-pullthrough-mirror.md) | Auditar se `ExecStartPost` já satisfaz reinstall; só criar Job se existir gap real. |
| A9 | **Rolling CP restart e helpers k3s valem o custo?** | [`kepler-k3s-microvm-cluster`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-19-kepler-k3s-microvm-cluster.md) | Decidir a partir de histórico de deploy/downtime, não preferência abstrata. |
| B5 | ~~**Ativar/verificar `k3s-manifest-reconcile`**~~ | módulo compartilhado k3s + Harbor RFC | **Resolvido 2026-07-15:** serviço ativo em cp-1/2/3 após o bounce. |
| B6 / O1 | ~~**Scrape e dashboard etcd**~~ | [`observability-continuation`](2026-07-03-observability-continuation.md) | **Resolvido 2026-07-15:** três endpoints `:2381` com leader e `up{job="etcd"}=1`; dashboard provisionado. |
| B7 / O2 | **Alertas KSM do cluster** | mesmo doc | CrashLoop, PVC, node, jobs; verificar firing e recovery. |
| B8 / O3 | **Labels de container no pipeline de métricas** | mesmo doc | Corrigir descoberta/labels antes de escrever alert rules por container. |
| O4 | **Fechar incidentes e cleanups restantes** | mesmo doc | Cada item precisa owner, evidência e regra de remoção. |

## Cluster HAI — HA, Hermes, OpenCode e tooling de agentes

| ID | Decisão / trabalho | Dono | Próximo gate |
|----|--------------------|------|--------------|
| A12 / HAI1 | **Quais extensões HA/voice sobrevivem** | [`home-assistant-ai-consolidation`](2026-07-02-home-assistant-ai-consolidation.md) | Resolver gates §5; escolher no máximo 0–2 extensões além do shadow stack. |
| HAI2 | **Deploy do shadow tool-caller HA** | mesmo doc | Resolver capacity gate; validar corpus/modelo/rollback antes de trocar pipeline live. |
| HAI3 | **Sandbox do Hermes antes de ampliar alcance** | [`hermes-deferred-improvements`](2026-06-29-hermes-deferred-improvements.md) P1 | Decidir docker socket/DinD vs blast radius atual. |
| HAI4 | **Merge/cadência do wiki Hermes + memory caps** | mesmo doc P2/P4 | Revisar qualidade; escolher cadence; medir tokens antes/depois dos caps. |
| HAI5 | **Pin/healthcheck do OCI Hermes** | mesmo doc P5 | Corrigir primeiro no `hermes-flake`, depois bump e deploy no consumer. |
| HAI6 | **Reabrir agentmemory?** | mesmo doc P6 | Default: não. Reabrir só com falha demonstrada de keyword/file recall. |
| HAI7 | ~~**TokenSave: benchmark ou remover**~~ | [`tokensave-dataplatform-eval`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-02-tokensave-dataplatform-eval.md) | **Resolvido 2026-07-15:** benchmark executado; eval removida por não provar o contrato de adoção. |
| HAI8 | **OpenCode LiteLLM routing** | [`opencode-litellm-routing`](2026-07-12-opencode-litellm-routing.md) | Implementado; verificar no próximo `switch laptop`, depois graduar RFC. |

## Cluster S — secrets, custódia e caudas IaC

| ID | Decisão / trabalho | Dono | Próximo gate |
|----|--------------------|------|--------------|
| A10 / S1 | **Segundo guardião da unseal key + root break-glass** | [`openbao-root-recovery`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-30-openbao-root-recovery.md) | Definir custódia fora do host antes do próximo incidente. |
| B11 / S2 | **Cauda servarr→Vault** | [`vault-secrets-platform`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-06-29-vault-secrets-platform.md) | Reavaliar somente chaves ainda em sops por intenção; registrar exceções. |
| S3 | **Provider admission para Terraform stateful** | [`stateful-stack-release-hardening`](2026-07-13-stateful-stack-release-hardening.md) | Nenhum provider ganha ownership sem export/import/plan/recovery proof. |

---

## Ordem sugerida

1. **O0/S0** — corrigir bootstrap Argo/ESO; hoje `external-secrets` e `demo` estão Degraded.
2. **R1/R2** — não executar; fechar evidence manifests e trazer aprovação.
3. **HAI8 + A4** — graduations documentais já decididas.
4. **H1** — sudo agora desbloqueado por deploy-rs, mas exige command audit.
5. **B7/O2** — alertas KSM depois de restaurar ESO/demo.
6. **N3/N4** — decidir placement antes de qualquer separação de containers.
7. Restante por trigger explícito; ausência de trigger não é trabalho pendente.

## Já fechado — não retrabalhar

- A1 lazy-trees: RFC aposentado; árvore Git pequena, nenhum gargalo medido.
- A11 HA declarative: Phase 1 implementada; HAOS retido até necessidade concreta.
- Harbor declarative: oneshot NixOS é o desenho aceito; static compose abandonado.
- Deploy layer: deploy-rs é o padrão da frota.
- Restore Voyager: PASS 2026-07-04.
- Fleet ESP: Pathfinder, Orion e Kepler concluídos; Laptop retirado do escopo.
