# RFC: Fleet-wide dependency automation on self-hosted Renovate

**Status:** ✅ Implemented (2026-07-11) — Phases 0–3 shipped; see **As-built** at the end. Two follow-ups tracked there (servarr docker automerge, homelab-iac IaC import).
**Author:** Erik (eribpf)
**Supersedes (partially):** the servarr Dependabot rollout of 2026-07-11 (`ErikBPF/servarr` commits `0442d25`…`4df703a`) — kept running until Renovate proves out, then retired.
**Owner concern:** fleet dependency-update automation (a cross-repo, D9 publish-and-pin-adjacent concern; recorded here because `desktop-nixos` is the fleet design SSOT).

## Summary

Consolidate all fleet dependency-update automation onto **one self-hosted Renovate**, run as a scheduled GitHub Action, authenticated by a self-created GitHub App, scoped to an explicit fleet-repo allowlist, driven by a shared config preset. Auto-merge is CI-gated, cooldown-delayed, and digest-pinned; major/platform bumps stay PR-only. This replaces the per-repo Dependabot direction (and the `*.compose.yml` rename it forced) with a single tool that covers docker-compose (arbitrary filenames), kubernetes, helm, terraform, nix, pip, and github-actions.

## Context & problem

- The fleet ran a **self-hosted Renovate container** and retired it (2026-07-11) — not for lack of capability, but for **operational pain**: an expired GitHub PAT (401 crash-loop) on an unmanaged orphan container.
- The interim direction was **GitHub Dependabot per repo**. Validation surfaced hard limits:
  - Dependabot's `docker-compose` fetcher only matches `/(docker-)?compose.../` filenames, forcing a fleet-wide `*.yml → *.compose.yml` rename (32 files + symlink-shim debt).
  - Dependabot cannot CI-gate auto-merge without branch protection (Pro-only on private repos), forcing a `workflow_run` workaround.
  - Dependabot's Kubernetes support is weak — `homelab-gitops` needs Renovate regardless, so a Dependabot-everywhere plan still ends up running **two** bots.
- A BMAD party elicitation (2026-07-11) grilled the plan and concluded: run **one** tool, and make it Renovate — but self-hosted, with the ops failures that killed v1 designed out, and with hardened auto-merge (cooldown + digest + real CI gates).

## Decision

1. **One tool, fleet-wide: self-hosted Renovate.** Retire Dependabot once Renovate covers each repo (no coverage gap during transition).
2. **Runner:** `renovatebot/github-action` on a `schedule:` cron in a dedicated runner repo (or an existing ops repo). No host container.
3. **Auth:** a **self-created GitHub App** under `ErikBPF` (private-key auth, no PAT expiry), installed only on allowlisted repos. Not the Mend-hosted cloud app.
4. **Scope:** an **explicit repository allowlist** — never unscoped `autodiscover` (ErikBPF has ~50 repos, most of them employer/unrelated).
5. **Config:** a **shared preset** (`github>ErikBPF/<runner-repo>`) that repos `extends`; per-repo overrides live in each repo's `renovate.json`.
6. **Guardrails:** global `minimumReleaseAge` (cooldown), `pinDigests: true`, and **no `automerge` lane without a real build/runtime CI gate** in that repo.

## Scope — repository allowlist

Fleet sisters only:

`servarr`, `homelab-iac`, `homelab-gitops`, `hermes-flake`, `hermes-skills`, `opencode-flake`, `codex-flake`, `home-assistant-config`, `kindle-dash`, `desktop-nixos` (nix inputs — TBD, see open decisions).

Excluded: `klipper-biqu` / no dep manifests; `ha-agent` local-only (never on GitHub); and **every non-fleet ErikBPF repo** (nstech/work, keyboard configs, dotfiles).

## Architecture

- **Runner repo** holds: the scheduled Action workflow, the shared preset (`default.json` / `renovate.json` preset), and the App secrets (`RENOVATE_APP_ID`, `RENOVATE_PRIVATE_KEY`) as Actions secrets.
- The Action mints an **App installation token** per run and passes it to Renovate as `token`.
- Renovate reads an explicit `repositories: [...]` list (the allowlist).
- Each managed repo carries a minimal `renovate.json` → `"extends": ["github>ErikBPF/<runner-repo>"]` + local `packageRules`.
- Auto-merge: `automerge: true` with `platformAutomerge: false` → **Renovate self-merges via the API once the branch's CI checks pass** — no branch protection required (the key advantage over Dependabot; smoke-tested in Phase 0).

## Auto-merge policy (tiered)

| Repo / surface | Cadence | Auto-merge | PR-only |
|---|---|---|---|
| flakes (opencode/codex) — github-actions | monthly | — | actions (low traffic) |
| flakes — nix flake.lock inputs | weekly | patch/minor after CI | major |
| home-assistant-config — actions | weekly | — | **all** (repo policy = manual merge) |
| hermes-flake — actions | monthly | minor/patch after CI | major |
| servarr — docker-compose | daily | minor/patch after CI (cooldown) | major, **digest** |
| kindle-dash — pip/docker/actions | daily | pip+actions minor/patch after CI | docker base, majors |
| homelab-iac — terraform | daily | **none** (merge ≠ apply; no CI plan gate) | all terraform |
| homelab-iac — github-actions | daily | minor/patch after CI | major |
| homelab-gitops — helm/images | daily | obs + own-apps patch/minor after kubeconform | **platform floor** (argo-cd, traefik, ESO, csi), majors |

## Guardrails

- **Cooldown:** `minimumReleaseAge: "3-5 days"` — dodges yanked/broken same-day `x.y.0` releases (the cyberchef-v11 class trap).
- **Digest pinning:** `pinDigests: true` — a moving tag can be re-pushed; digests make every bump explicit and revertible.
- **CI gate before automerge:** each automerge lane requires a build/runtime check, not a syntax check:
  - `kindle-dash`: `docker build` + a Pillow smoke-render on PR.
  - `homelab-gitops`: `helm template | kubeconform` (Argo auto-syncs `main`, so merge == deploy).
  - `homelab-iac`: `tofu validate` (real `plan` needs creds + wired LAN → terraform stays PR-only).
- **Rollback AC:** every automerge lane must revert with one `git revert` + re-sync/redeploy.
- **Notification:** Renovate has no native Discord — route via a small Action step (reuse `DISCORD_DEPLOYS_WEBHOOK`) and, for `homelab-gitops`, Argo Notifications so a degraded auto-synced app alerts instead of hiding behind `selfHeal`.

## Rollout phases

- **Phase 0 — smoke-test the model (cheap):** create the App; stand up the runner repo + cron Action; onboard **one** low-risk repo (a flake) with `automerge: false` + dependency dashboard. Prove App auth works, PRs open, and CI-gated self-merge fires when enabled.
- **Phase 1 — safe wave:** shared preset; onboard the flakes + `home-assistant-config` (PR-only) + `hermes-flake`. Global cooldown + `pinDigests`. Enable Renovate's nix manager to close the stale `flake.lock` gap (nixpkgs = the real security surface).
- **Phase 2 — gated automerge:** build the CI gates → enable tiered automerge.
- **Phase 3 — consolidate:** fold the existing `homelab-gitops` `renovate.json` (helmv3 + dependency dashboard) into the preset and enable the image manager; onboard `servarr` and **retire its Dependabot** (`dependabot.yml` + `dependabot-auto-merge.yml`) once Renovate covers it. Decide the fate of the `*.compose.yml` rename (leave vs revert).

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| `autodiscover` onboards ~40 non-fleet/employer repos | Explicit allowlist only; never `autodiscover: true` |
| App private key leak = write to all fleet repos | Store as Actions secret in one runner repo; scope App to allowlist; rotate on suspicion |
| Auto-merge ships a compromised/broken minor | Cooldown + digest pin + CI gate; supply-chain-privileged deps (publish/OIDC actions) PR-only |
| `homelab-gitops` merge == live deploy (Argo `selfHeal` masks breakage) | kubeconform gate + tiered (platform floor PR-only) + Argo health notifications |
| PR/notification firehose across ~10 repos | Grouping in the preset + waved rollout + `automerge:false` first, watch, then enable |
| Reviving the tool that just failed operationally | App auth (no PAT expiry) + Action runner (no orphan container) — the two v1 failure modes designed out |
| Coverage gap during transition | Keep servarr Dependabot live until Renovate proves out in Phase 0-2 |

## Open decisions

- Runner repo: new dedicated repo, or host in an existing one (`homelab-iac`)?
- Include `desktop-nixos` (nix flake inputs) in scope, or leave its inputs to `nix flake update` / existing lanes?
- `servarr` `*.compose.yml` rename: leave (working, harmless) or revert once Renovate is authoritative?
- Cooldown length (3 vs 5 days) and whether to differ it per surface.

## Verification / done criteria

- Phase 0: a flake repo shows Renovate PRs + a CI-gated self-merge, authed by the App, with zero non-fleet repos touched.
- Each phase: onboarded repos get grouped PRs on schedule; automerge fires only after the repo's CI gate is green; Discord pings land in `#deploys`.
- End state: one Renovate config, one runner, Dependabot removed from servarr, no non-fleet repo onboarded.

## As-built (2026-07-11)

Phases 0–3 shipped in one session. Details + gotchas in `memory/renovate_phase0.md`.

**Runner + auth.** Dedicated private repo **`ErikBPF/renovate-config`** (open decision resolved: *new repo*, not `homelab-iac`) holds the scheduled Action (`renovatebot/github-action`, pinned full version — the action has no moving major tag), `config.js` (explicit `repositories` allowlist — `onboarding:false`; **never `autodiscover`**), and `default.json` shared preset. Auth = self-created GitHub App **`erikbpf-fleet-renovate`** (app id `4274557`, install `145943411`). App key stored in `desktop-nixos` sops (`renovate.{app_id,private_key}`) **and** as `RENOVATE_APP_ID`/`RENOVATE_PRIVATE_KEY` Actions secrets on the runner repo. **Required App permissions** (three surfaced only by running it): Contents, Pull requests, **Issues**, **Commit statuses**, **Workflows** (all RW), Checks + Metadata (R). A missing permission shows up as the misleading *"Repository has changed during renovation - aborting"*.

**Onboarded (6 repos + the runner as preset source):** `opencode-flake`, `codex-flake`, `hermes-flake`, `home-assistant-config` (PR-only per repo policy — onboarded via PR #55), `servarr` (custom `docker-compose` `managerFilePatterns` for its `*.compose.yml`), `homelab-gitops` (its standalone `renovate.json` folded into the shared preset). Each carries `renovate.json` → `extends: ["github>ErikBPF/renovate-config"]`. **Scope correction:** `hermes-skills` dropped from the RFC scope list — no dependency manifests.

**Preset guardrails:** `config:recommended` + `:dependencyDashboard`, `minimumReleaseAge: "3 days"` (cooldown resolved to a uniform 3d), `pinDigests: true`, nix manager enabled (covers `flake.lock`). `automerge` off by default; **`platformAutomerge: false`** so Renovate self-merges via the App API (no branch protection needed — the key advantage over Dependabot).

**Tiered automerge (CI-gated):** nix `flake.lock` non-major on all flakes (preset); `github-actions` non-major on `hermes-flake` (in *that repo's* `renovate.json`, not the shared preset — per-repo policy stays per-repo). CI gates verified auto-running + green on Renovate PRs (`check`/`package-build`/`build` + `renovate/stability-days`). Live merges are cooldown-gated (fire once a matching PR ages past 3 days). `homelab-gitops` got a `kubeconform` **`validate.yml`** gate (Argo auto-syncs `main`, so merge == deploy).

**Dependabot retired:** both `hermes-flake` and `servarr` (RFC's end-state).

**Deliberately not tracked:** internal Harbor images (`harbor.homelab.pastelariadev.com/**`) — the host is NXDOMAIN publicly, unreachable from GitHub cloud runners; those images are owned + bumped by their source repo (D9 publish-and-pin). Preset rule disables that datasource to avoid the wasted lookup.

### Follow-ups (not yet done)

- **`servarr` docker automerge** — left PR-only. Needs its `validate.yml` confirmed running on Renovate PRs + a decision on the untrackable private-Harbor images before enabling.
- **`homelab-iac` `github/repos` import** — a `renovate-config = { visibility = "private" }` entry is staged in that repo (drift-proof runner-repo settings), pending a `terragrunt` import run with its `.env`.
- **`desktop-nixos` scope** (open decision) — left **out**; its `flake.lock` stays on existing `nix flake update` lanes for now.
- **Discord notifications** — the `#deploys` webhook routing (Risks table) is not wired yet.
- **llama.cpp digests** (`servarr`) — the `ghcr.io/ggml-org/llama.cpp` refs are bare `@sha256` with no tag, so Renovate can't determine a digest bump (logs a benign "could not determine new digest"). Add the rolling tag (`:server-vulkan@sha256:…` on orion, `:server-cuda@sha256:…` on kepler) to make them Renovate-trackable.
