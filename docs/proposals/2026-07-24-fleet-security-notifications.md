# Fleet security notifications

**Status:** Implemented — producer workflows and per-repository credentials are
ready; private hosted runs remain limited by GitHub billing.
**Date:** 2026-07-24
**Owner:** Cross-repo policy in `homelab`; implementation stays with each
component repository.

## Problem

Security findings currently surface through several unrelated paths:

- GitHub Dependabot and secret-scanning alerts;
- Renovate security updates;
- Trivy image and IaC scans;
- Gitleaks and repository-specific secret contracts;
- Cosign verification in release pipelines;
- infrastructure drift and Grafana operational alerts.

GitHub remains the finding system of record, but urgent findings have no
consistent operator-facing route. Generic workflow-failure notifications are
too noisy: most recent failures are ordinary pull-request feedback, not active
security incidents.

Current audit:

- Renovate scans six repositories but its GitHub App cannot read Dependabot
  alerts.
- Public repositories use GitHub secret scanning and push protection.
- GitHub secret scanning is currently disabled on these private repositories:
  `renovate-config`, `servarr`, `homelab-gitops`, `home-assistant-config`,
  `hermes-skills`, and `klipper-biqu`.
- Gitleaks Actions run only in `kindle-dash` and `klipper-biqu`; some other
  repositories have narrower custom secret checks.
- Trivy runs in `kindle-dash` and `homelab-iac`.
- No repository currently publishes CodeQL/code-scanning results.

No open Dependabot or secret-scanning alerts were found in repositories where
those features were enabled during the 2026-07-24 audit. Disabled coverage
means the remaining repositories cannot support the same claim; no active
compromise is otherwise known.

## Decisions

### D1 — Dedicated `#security` Discord channel

Security findings do not share `#deploys`: a release feed must remain quiet
enough to show actual deployments. `#security` receives new actionable
findings and resolution updates.

Only an exploited vulnerability, exposed credential, public-surface policy
breach, or credible data-loss path is duplicated into `#incidents`.

Argus does not watch `#security` in phase 1. Scanner text and dependency
metadata are untrusted inputs. Adding the channel to Argus requires a later
gate proving trusted message normalization while its terminal remains
disabled.

### D2 — GitHub/scanner remains authoritative

Discord contains a compact pointer, never the full report. It must not contain:

- secret values or matched source lines;
- scanner logs;
- environment variables;
- private repository content;
- untrusted Markdown mentions.

Each message contains:

- severity and finding class;
- repository and default-branch/release ref;
- stable finding ID or CVE;
- affected package, image, or policy;
- fixed version or immediate containment when known;
- link to the private authoritative finding;
- lifecycle state: `OPEN`, `RESOLVED`, or `DISMISSED`.

Webhook payloads disable user/role mentions by default. Only the trusted
formatter may mention Erik for a critical finding.

### D3 — Severity routing

| Finding | Route |
|---|---|
| Critical/high dependency vulnerability on the default branch or release | `#security` |
| Secret detected, bypassed, or committed | `#security` + `#incidents` |
| Signature/provenance verification failure on a release | `#security` + `#incidents` |
| IAM, firewall, public-ingress, or GitHub App permission drift | `#security`; duplicate to `#incidents` when exposure is live |
| Medium/low vulnerability | GitHub dashboard/issue only |
| Pull-request scanner failure with no default-branch exposure | Pull-request check only |
| Clean scan or no-op scheduled run | No Discord message |

### D4 — Event notifications, not polling summaries

Notify once when a finding opens. Repeated scheduled scans must not repost
unchanged findings. Resolution or dismissal posts a linked follow-up only when
the producer already retains the original Discord message ID; otherwise the
authoritative GitHub finding carries lifecycle state.

If a source cannot provide stable IDs and lifecycle events, keep it in GitHub
until it can. A daily “all clear” or vulnerability count is explicitly out of
scope.

## Ownership and transport

- `renovate-config`: dependency-alert access and Renovate security-update
  classification.
- Each component repo: its scanner configuration and default-branch/release
  failure hook.
- `homelab-iac`: Discord channel/webhook resource if managed through an
  external API.
- OpenBao `secret/shared/discord`: runtime webhook value.
- `desktop-nixos`: render the webhook only to host workloads that need it.
- GitHub Actions: use a GitHub Actions secret or organization secret; they
  cannot reach runtime OpenBao and must never acquire a Vault credential.

Use one formatter contract across GitHub Actions and host workloads, but do not
create a fleet notification service in phase 1. A shared JSON example and
contract test are enough; each source posts directly. Producers do not add
state solely for Discord threading.

## Rollout

### Phase 0 — access and channel

1. Create `#security` and its webhook.
2. Grant the Renovate GitHub App `Dependabot alerts: read`; verify warning-free
   access on every managed repository.
3. Store webhook values in the trust domain where they execute:
   GitHub Actions secret for Actions, OpenBao for runtime jobs.
4. Send one redacted sample and verify mentions are disabled.

### Phase 1 — highest-signal producers

1. Renovate: notify only newly created security PRs and failures preventing
   those PRs.
2. Kindle release: notify signature/provenance failures.
3. `homelab-iac`: notify critical/high Trivy findings and live public-surface
   policy drift.
4. Private config repos: add Gitleaks to `servarr`, `homelab-gitops`, and
   `home-assistant-config`; notify only default-branch findings or explicit
   bypasses.

Implementation update — 2026-07-24:

- `servarr`, `homelab-gitops`, and `home-assistant-config` now carry dedicated
  Gitleaks workflows on pull requests, `main`, and manual dispatch.
- The workflows use read-only GitHub permissions, full-history checkout, and
  the same immutable action pins already proven by `kindle-dash` and
  `klipper-biqu`.
- A local full-history scan found 20 candidate matches in `servarr` and 32 in
  `home-assistant-config`; the latest commit range is clean in all three repos.
  Audit and rotate any real historical credentials before creating an ignore
  baseline. Do not suppress these findings merely to make manual scans green.
- Discord posting is not enabled before `#security` and its scoped Actions
  secret exist.
- Dormant notification steps are prepared in those three workflows and in
  `renovate-config`; they post only default-branch Gitleaks failures or a hard
  Renovate runner failure after `DISCORD_SECURITY_WEBHOOK` is configured.
- `kindle-dash` is prepared to post a redacted provenance/signature failure to
  both `DISCORD_SECURITY_WEBHOOK` and `DISCORD_INCIDENTS_WEBHOOK`. Missing
  secrets produce a workflow notice, not a failed notification step.
- Every prepared payload disables Discord mentions and withholds scanner,
  signature, and secret-match output.
- `homelab-iac` Trivy is blocking for critical/high findings and has the same
  dormant, redacted security hook. A local scan found zero critical/high
  findings before enabling the gate.
- Every repository in `repos.json` now has a dedicated Gitleaks workflow and
  the same dormant security hook. This includes `desktop-nixos`,
  `hermes-flake`, `hermes-skills`, `klipper-biqu`, `opencode-flake`,
  `codex-flake`, `ha-harness`, and `cosmo-notes`.
- Local full-history scans of those eight additional repositories were clean
  except for nine candidate matches in `desktop-nixos`; all eight latest
  commit ranges were clean. Audit and rotate any real historical credentials
  before creating an ignore baseline.
- Redacted triage locates the historical candidates in documentation,
  migration/audit artifacts, configuration backups, ESPHome configuration,
  and one test private-key fixture. No candidate exists in the current working
  tree of any of the 13 fleet repositories. History remains immutable evidence:
  rotate any candidate proven real; allowlist only a narrowly identified
  fixture or non-secret identifier.
- A fleet contract prevents any repository in `repos.json` from losing its
  webhook reference or mention-disabled payload.
- `ha-harness` and `cosmo-notes` are manual-only while GitHub blocks private
  hosted-runner jobs for account billing. Their full histories and current
  trees pass local redacted Gitleaks scans; each README carries the routine
  working-tree command. Restore push/PR triggers only after a hosted or
  self-hosted runner can actually start.

Hook activation requires only repository secrets:

| Repository | Required secret |
|---|---|
| Every repository in `repos.json`, plus `renovate-config` | `DISCORD_SECURITY_WEBHOOK` |
| `kindle-dash` | `DISCORD_SECURITY_WEBHOOK`, `DISCORD_INCIDENTS_WEBHOOK` |

Activation update — 2026-07-25:

- `#security` and its dedicated incoming webhook exist.
- `DISCORD_SECURITY_WEBHOOK` is installed and verified as a per-repository
  Actions secret on every repository in `repos.json` and `renovate-config`.
- A redacted, mention-disabled test message reached `#security`.
- The plaintext handoff file was deleted after distribution.
- No host workload currently posts security findings, so the webhook is not
  copied into OpenBao until a runtime producer exists.

### Phase 2 — evaluate, then stop

After 30 days, measure:

- unique findings;
- duplicate messages;
- messages without operator action;
- time from finding to acknowledgement and resolution.

Keep direct posting if volume stays low. Add a central dedupe/formatting bridge
only when duplicate sources or lifecycle updates demonstrably require one.
CodeQL is not part of this rollout; add it per repository only when language
and threat model justify its runtime and maintenance cost.

## Acceptance

- A high-severity dependency fixture passes the formatter contract; one
  explicitly labeled test payload creates a redacted `#security` message
  linked to a non-sensitive test target.
- A synthetic secret finding contains no match, source line, or credential and
  also reaches `#incidents`.
- Re-running an unchanged scan creates no second top-level message.
- Resolution updates the original thread only when the producer already
  retains its message ID; otherwise GitHub remains the lifecycle record.
- Medium/low and pull-request-only findings remain in GitHub.
- Renovate completes without “Cannot access vulnerability alerts”.
- No workflow receives a Vault credential.
- Argus cannot consume `#security` messages in phase 1.

## Resolved decisions

1. Channel: `#security`.
2. GitHub placement: per-repository secrets.
3. Mentions: disabled; rely on channel notification settings.
