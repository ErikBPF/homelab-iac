# DeepSeek Harness remote tmux workspaces

**Status:** Implementation planned; PL and IP complete; no runtime or infrastructure change applied
**Date:** 2026-08-24
**Owners:** `deepseek-harness-flake` for the pinned Harness and TUI packages; `desktop-nixos`
for Gemini, launchers, persistent state, and backup; `homelab-iac` for the
scoped LiteLLM key, Vault handoff, and tailnet policy; `homelab` for this
cross-repository contract

## Destination

Run DeepSeek Harness on the existing Gemini remote development environment
with eight concurrent slots per Git checkout. Each slot has its own writable
Harness home and conversation log, while every slot consumes the same pinned
package, read-only configuration overlay, provider routes, and scoped runtime
credentials. SSH and tmux keep live processes attached to Gemini when a client
disconnects; persistent storage keeps session data after process or host
restart. A pinned terminal profile provides interactive `/resume` and `/model`;
the shipped Web profile remains the recovery surface.

The owning behavior contract is
[`deepseek-tmux-workspaces.feature`](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/behaviors/deepseek-tmux-workspaces/deepseek-tmux-workspaces.feature).
It remains `@unautomated`: implementation tests bind the shell/Nix seams, not a
new Gherkin runtime.

## Accepted scope

- Reuse Gemini, the NixOS container on Orion already designated as the
  remote-primary development environment.
- Create one persistent state volume with a writable shard for each canonical
  checkout path and slot `01` through `08`.
- Add one tmux launcher that creates or attaches eight numbered slot shells.
- Add interactive TUI, one-shot headless, and loopback-only Web helpers.
- Run with `DSH_PERMISSION_MODE=danger-full-access` and
  `DSH_TELEMETRY_DISABLED=1` inside Gemini only.
- Publish `deepseek-v4-pro` from the existing reviewed OpenCode Zen catalog and
  expose it with `deepseek-v4-flash` through a dedicated two-model LiteLLM key
  handed to Gemini through Vault.
- Route `gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna` through Harness's
  native `openai-codex` provider and one shared DSH-owned ChatGPT OAuth grant.
- Pin one out-of-tree terminal profile only after its build, version,
  `/resume`, `/model`, and persisted-session compatibility canary passes.
- Back up non-secret Harness state to the existing encrypted Kepler Restic
  target and prove one isolated restore.

## Non-goals

- No new VM, host, Kubernetes workload, database, session daemon, or public
  Web endpoint.
- No home-grown TUI, fork, or mutable `dsh plugin add` during deployment. The
  candidate is the pinned MIT-licensed `@nexlineai/dsh-tui@0.1.1`; failure at
  its leaf gate leaves Web as the supported resume surface.
- No GPT-5.6 route through LiteLLM or the OpenCode Zen key.
- No reading, copying, translating, or symlinking Gemini's existing
  `~/.codex/auth.json`. Harness owns a separate OAuth grant because upstream
  does not consume Codex CLI's private credential file.
- No shared writable `$DSH_HOME` between processes.
- No automatic Git worktree creation, branch creation, reset, merge, or
  deletion.
- No guarantee that tmux processes survive Gemini or Orion restart. Persisted
  conversations survive; arbitrary processes and in-flight turns do not.
- No synchronization of live Harness state through Syncthing.
- No changes to the existing Endeavour `dp` alias. It remains the local Web
  entry point.

## Grounded evidence

### Existing fleet capability

- Gemini already provides tailnet-only SSH, persistent home storage, tmux,
  repository sync, coding-agent packages, and user lingering.
- The existing Gemini proposal makes it the remote-primary code host and
  explicitly rejects another nested terminal stack.
- `desktop-nixos` already owns `tmux-repo`, an eight-window `tmux-homelab`
  launcher, the Gemini container, and the DeepSeek Harness Home Manager module.
- Kepler already accepts encrypted Restic backups through the dedicated
  `restic-offsite` path.
- LiteLLM model/key and OpenBao handoff patterns already exist in
  `homelab-iac`; this proposal adds a consumer, not a second secret platform.
- The normalized OpenCode Zen catalog contains `deepseek-v4-pro` with reviewed
  capacity/pricing metadata, while the production LiteLLM manifest does not
  publish it. S1 owns that one missing route.
- Gemini already runs the declarative Codex package with mutable authentication
  under `~/.codex`; Harness intentionally cannot consume that `auth.json`.

### Upstream Harness constraints

- `$DSH_HOME` selects the Harness home. Profiles live beneath its `profiles/`
  directory, and the home-level patch plus `--patch` overlay the bundled
  profile configuration.
- `dsh --profile headless "task"` creates one fresh persisted session, prints
  its final response, and exits. It is not an interactive attach or resume
  client.
- The launcher can pass application arguments to an installed TUI profile, but
  upstream ships no TUI bundle. `/resume` is therefore a pinned third-party
  capability, not an upstream CLI guarantee.
- The Web profile owns the upstream-supported session browsing and resume
  behavior.
- JSONL persistence is append-only and durable, but a session has a
  single-writer contract. Multiple processes must not write the same session.
- `$DSH_HOME/storages` uses whole-file atomic writes without a cross-process
  lock. Multiple processes sharing one home can still overwrite settings.
- Credential precedence is inherited environment, then
  `$DSH_HOME/.credentials.yaml`, checkout `.env`, and `$DSH_HOME/.env`.
  The credential provider accepts an explicit path and uses a cross-process
  writer lock, so OAuth can be shared without sharing session/settings state.
- The native `openai-codex` route persists its own OAuth record through the DSH
  credential plane. The shipped CLI has no `auth` command, so the leaf gate
  must provide or prove one bounded login surface.
- `danger-full-access` bypasses filesystem confinement; network and process
  visibility are outside the sandbox-mode promise.

## PL decision map

### Actors and outcomes

| Actor | Required outcome |
|---|---|
| Operator | Attach over SSH, select one checkout, see eight stable slots, and run interactive, Web, or one-shot CLI tasks. |
| Harness process | Receive one writable home, one writer lock, one checkout cwd, immutable configuration, and scoped credential sources. |
| Fleet maintainer | Rebuild the whole surface from reviewed Nix/IaC without copying mutable profiles between machines. |
| Recovery operator | Restore session state without restoring or exposing credentials. |

### Decisions

| ID | Decision | Evidence | Consequence |
|---|---|---|---|
| D1 | Extend Gemini; do not add a host. | Gemini already owns remote-primary coding, SSH, tmux, and synced repositories. | Orion remains the availability and resource boundary. |
| D2 | One state volume, one `$DSH_HOME` per checkout path and slot, plus one shared credentials document. | Harness settings/session storage lacks safe multi-process home locking; its dedicated credential document has its own cross-process lock. | Conversation state stays sharded while one OAuth grant serves all slots. |
| D3 | Keep shipped headless for one-shot automation; gate one pinned third-party TUI for interactive CLI use. | Upstream passes app arguments to installed profiles but ships no TUI; the candidate implements `/resume` over Harness sessions. | CLI resume is available only after the leaf canary; Web remains fallback. |
| D4 | Bind every Web process to loopback and forward explicitly over SSH. | No supported remote CLI attaches to the Web host. | No new network/IaC ingress surface. |
| D5 | Split models by owned route: two DeepSeek aliases through LiteLLM, three GPT aliases through native `openai-codex`. | DeepSeek already follows the scoped gateway pattern; Codex subscription models belong on the existing ChatGPT/Codex account path. | LiteLLM budget controls only DeepSeek usage; Codex account limits remain separate. |
| D6 | Use `flock` as the per-slot writer gate. | The dangerous case is two live processes targeting one home. | A second writer fails before Harness boots. |
| D7 | Keep checkout write isolation operator-owned. | Eight YOLO agents can race on one checkout, while repo policy already defines manual worktrees. | Launcher documents the risk and never mutates Git topology. |
| D8 | Back up only non-secret state to Kepler Restic. | Session history is useful but not crown-jewel state; the encrypted receiver already exists. | Daily/weekly/monthly retention; no new off-premise tier. |

### Dependencies and frontier

```text
deepseek-harness-flake pinned Harness + TUI + bounded Codex-login surface
                │
homelab-iac one model route + two-model key + Vault handoff + Orion→Vault ACL
                │
desktop-nixos Gemini volume + shared OAuth document + credential render + launcher
                │
one-slot canary → two-slot concurrency → eight-slot rollout
                │
Restic backup + isolated restore drill
```

The only human-owned deployment choice still open is the LiteLLM monthly
budget. The proposed ceiling remains USD 5/month; `homelab-iac` apply stays
blocked until the operator accepts or replaces it. This is a ceiling, not a
spend authorization and applies only to the two DeepSeek routes. Codex usage is
governed by the signed-in ChatGPT account's limits. The TUI and native Codex
login are technical gates: if either fails G0, return to planning rather than
routing GPT models through LiteLLM.

## Architecture

### Persistent state identity

The launcher resolves the checkout with `git rev-parse --show-toplevel`. Its
workspace key is a readable checkout basename plus the first twelve hex digits
of SHA-256 over the canonical absolute path. That avoids collisions between
same-named checkouts without adding a registry.

```text
/var/lib/gemini/deepseek-harness/             # Orion-owned persistent volume
├── credentials/
│   └── .credentials.yaml                    # shared DSH OAuth record; 0600
└── workspaces/
    └── <basename>-<path-hash>/
        ├── 01/                               # DSH_HOME for slot 01
        ├── 02/
        └── … 08/
```

Gemini bind-mounts the volume read-write at
`~/.local/state/deepseek-harness`. Directories are `0700` and owned by the
Gemini user; the shared credential document is `0600`. Each shard stores a
non-secret identity marker containing the canonical checkout path and slot.
Moving a checkout intentionally resolves a new workspace; recovery is an
explicit state move, not a hidden alias table.

The per-home profile directories remain recreatable cache seeded from pinned
packages; runtime mutation is never authoritative. Behavior comes from:

- the pinned `deepseek-harness-flake` input;
- Home Manager environment defaults;
- one Nix-store `cordis.patch.yml` supplied last through `--patch`;
- launcher arguments for cwd, profile, host, and port.

### Public CLI seams

Only five commands are required on Gemini:

| Command | Contract |
|---|---|
| `dsh-repo [checkout]` | Create or attach one tmux session with slot shells `01`–`08`; refuse to replace a mismatched existing session. |
| `dsh-codex-login` | Run the bounded native `openai-codex` OAuth flow and write only its grant into the shared DSH credential document. |
| `dsh-tui` | In the current slot, acquire its lock and start the pinned interactive profile; `/resume` lists/continues persisted sessions and `/model` selects an allowed alias. |
| `dsh-headless "task"` | In the current slot, acquire its lock, run one fresh persisted headless task, return Harness stdout/exit status, release the lock. |
| `dsh-web [port]` | In the current slot, acquire its lock, verify the port is free, bind Web to `127.0.0.1`, and pass `--no-open`. |

`dsh-repo` puts `DSH_WORKSPACE_ROOT` and `DSH_SLOT` into each child shell; it
does not put provider credentials into the tmux server environment. The three
runner helpers read the Vault-rendered LiteLLM key only when they exec Harness;
the native Codex provider reads its grant through the explicit shared
credential-document path.

Daily remote entry stays boring:

```bash
ssh gemini
cd ~/Documents/erik/homelab
dsh-repo
```

Interactive CLI use inside a slot:

```text
dsh-tui
/resume
/resume 1
/model gpt-5.6-terra high
```

Headless use inside a slot:

```bash
dsh-headless "inspect the failing contract and propose the smallest fix"
```

Remote Web use, with the same port on both ends:

```bash
# client
ssh -L 3081:127.0.0.1:3081 gemini

# Gemini slot 01
dsh-web 3081
```

Ports `3081` through `3088` are the documented slot convention, not a global
allocator. An occupied port fails closed; the caller may choose another
explicit port.

### Permission and checkout boundary

Every runner exports:

```text
DSH_PERMISSION_MODE=danger-full-access
DSH_TELEMETRY_DISABLED=1
```

The immutable patch declares one lowercase `litellm` custom provider using
`api: openai-completions`,
`baseURL: https://litellm.homelab.pastelariadev.com/v1`,
`apiKeyEnv: LITELLM_API_KEY`, and exactly `deepseek-v4-flash` and
`deepseek-v4-pro`. It also narrows the native `openai-codex` catalog to exactly
`gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna`, with no API-key override.
The credential-provider row points every profile at the shared OAuth document.
Context, output, modality, and reasoning metadata come from the reviewed
catalogs. The patch disables competing routes so `/model` exposes only these
five choices. G0 verifies both providers before rollout; configuration claims
do not substitute for model calls. The default remains
`litellm/deepseek-v4-flash`; model changes are explicit per session.

The permission mode is the requested YOLO behavior. It disables Harness
filesystem confinement. Gemini's container boundary still separates the agent
from Orion's ordinary filesystem, except for explicitly mounted repositories,
state, and credential render. A scoped LiteLLM credential limits provider
blast radius but cannot make arbitrary same-user code trustworthy.

Slots isolate Harness state, not checkout writes. Two agents editing the same
checkout can overwrite one another. Independent write tasks use existing,
operator-created Git worktrees and launch `dsh-repo` from each worktree. The
launcher never creates or destroys them.

### Runtime credential path

`homelab-iac` first publishes `deepseek-v4-pro` from the existing OpenCode Zen
catalog, then creates a `deepseek-harness` LiteLLM key allowlisted only to it
and `deepseek-v4-flash`, with the accepted monthly budget and no management
role. The OpenBao handoff writes the generated value to
`secret/home/deepseek-harness-litellm`.

Orion runs a narrowly named Vault Agent render using its sops-bootstrap AppRole
credentials and the existing Discovery OpenBao endpoint. `homelab-iac` permits
only Orion-to-Discovery TCP 8200 for that fetch. Orion bind-mounts the rendered
file read-only into Gemini. The DSH runners export it only as
`LITELLM_API_KEY` for the declarative custom provider.

The key never enters Git, the Nix store, a DSH `.credentials.yaml`, tmux's
global environment, or Restic. Because YOLO tools run as the Gemini user, the
rendered key is discretion rather than a hard secret boundary. The meaningful
controls are its model allowlist, budget, revocability, container boundary,
and absence of administrative authority.

Separately, `dsh-codex-login` runs Harness's native `openai-codex` OAuth flow
against the operator's ChatGPT account and stores the resulting
`llm-pi-ai/openai-codex` grant in the shared DSH credential document. It does
not read or modify `~/.codex/auth.json`. The provider's own cross-process lock
serializes refresh writes from concurrent slots. The grant is mutable runtime
state, not Nix or Vault material, and is readable by same-UID YOLO tools; its
security boundary is therefore the Gemini container and account revocability,
not file permissions alone.

### Backup and recovery

Orion backs up `/var/lib/gemini/deepseek-harness` once daily to
`sftp:restic-kepler:/bulk/backups/restic-offsite/gemini-deepseek-harness` using
the existing encrypted Restic credential and receiver. Retention reuses the
fleet norm: seven daily, four weekly, six monthly snapshots.

Exclude the complete `credentials/` directory plus every `.credentials.yaml`,
`.env`, lock, socket, and temporary file.
The restore drill restores one disposable slot into a new directory, never
over the live tree, then uses the pinned Harness build to list or open its
session. A package bump is blocked until this compatibility probe passes for a
copied prior-version session.

## Party elicitation ledger

### Round 1

- **Operator/product:** eight slots must feel like the existing tmux workflow;
  reconnecting should not require reconstructing profiles or credentials.
- **Developer/architect:** a single writable home is smaller on paper but
  violates upstream multi-process storage assumptions. One parent volume with
  eight shards preserves the shared operational layer without shared writers.
- **Tester/operator:** persistence must distinguish client disconnect, process
  exit, and host restart. Only disconnect preserves live processes; the other
  two rely on persisted logs and explicit relaunch.
- **CodeHero/security:** YOLO, a plaintext gateway key, and an OAuth grant under
  the same Unix identity cannot be made into a strong secret boundary. Scope
  the key, isolate the container, exclude credentials from backup, and keep Web
  loopback-only.

### Round 2

- The operator preference for tmux was retained.
- A home-grown TUI was rejected. One small third-party profile is acceptable
  only as an exact, leaf-owned package pin with a live resume canary and Web
  fallback.
- The upstream Codex subagent bundle was rejected as the primary GPT route: it
  reuses native Codex configuration/authentication, but every call is an
  ephemeral child and the bundle does not expose per-call model selection. It
  cannot satisfy the TUI `/model` and persistent-parent-session contract.
- Automatic worktree creation was rejected because it would make the launcher
  a Git lifecycle owner and could mutate user state.
- A new remote host was rejected because Gemini already owns the exact role.
- CLI resume is conditional rather than fictional: the candidate supplies it,
  upstream does not, and a failed compatibility gate removes only the TUI.

## Plan grill

### Findings applied

| Lens | Failure found | Revision |
|---|---|---|
| Anti-consensus | “Shared persistence” could be misread as one shared `$DSH_HOME`. | Defined a shared volume with isolated homes and a hard writer lock. |
| First principles | Eight concurrent YOLO agents can race on repository files even when conversations are isolated. | Made file isolation a stated non-goal and existing worktrees the operator path. |
| Pre-mortem | A package upgrade could make old pre-release session logs unreadable. | Added copied-session compatibility before any bump and an isolated restore drill. |
| Boundary analysis | Web could accidentally bind the tailnet/LAN; a second process could corrupt settings. | Fixed loopback binding, explicit ports, occupied-port rejection, and per-slot `flock`. |
| Security | A shared unrestricted key would turn one prompt injection into broad provider access. | Added a dedicated non-admin key, model allowlist, budget, Vault handoff, and revocation-first rollback. |
| Supply chain | The available `/resume` TUI is a newly released third-party package with pre-release Harness dependencies. | Pin version and integrity in the leaf flake, run its tests/smoke/live canary, forbid runtime installs, and retain Web fallback. |
| Compatibility | One DeepSeek-specific adapter cannot truthfully advertise the requested GPT aliases. | Split the catalog: two models on explicit `litellm`, three on native `openai-codex`, then canary each route. |
| Credential ownership | Reusing `~/.codex/auth.json` would bind Harness to another product's private mutable format. | Use a separate DSH OAuth record at one explicit shared path; never parse or copy Codex CLI auth. |
| Revocation | Deleting DSH's local OAuth record signs the provider out locally but does not prove issuer-side revocation. | On suspected compromise, stop consumers and complete the OpenAI account-side revocation/recovery process before treating the incident as contained. |
| Reliability | “Persistent tmux” could imply survival across reboot. | Acceptance now distinguishes detach persistence from disk persistence. |
| Operability | Eight simultaneous sessions could be enabled before rate/lock behavior is known. | Rollout gates one slot, then two concurrent slots, then all eight. |
| Test quality | A prose `.feature` could be mislabeled as executable coverage. | Kept `@unautomated`; each implementation slice names its real RED check. |

### Accepted residual risks

- Orion or Gemini outage makes the remote workspace unavailable.
- Eight model calls can hit provider limits; the launcher does not add a job
  scheduler.
- Same-checkout concurrent writes can conflict.
- A YOLO process can read same-user files visible inside Gemini, including the
  runtime credential render or shared OAuth document if it discovers the path.
- Codex subscription limits are independent of the LiteLLM budget and can
  throttle several concurrent slots.
- The pre-release Harness session format can change; pinning and restore tests
  reduce, not eliminate, that risk.
- The terminal profile is young and outside upstream support; `/resume` may be
  withdrawn if it fails a package or session-compatibility gate.
- DSH's native Codex grant is separate from Codex CLI's cached login; account
  recovery or logout may require handling both sessions independently.

## IP: implementation seams

Candidate public seams were evaluated before slicing:

| Seam | Catches | Misses | Cost | Decision |
|---|---|---|---|---|
| Runner command contract | State identity, slot bounds, locks, env, argv, exit status | Nix deployment and live provider behavior | Low | Select |
| Leaf package check | Exact TUI/auth-profile pins, boot, prompt handling, and credential-record write | Real account/model availability | Low | Select |
| Nix evaluation/dry build | Package/module composition, mounts, services, secret paths | Live SSH, Vault, API, and Restic behavior | Existing | Select |
| IaC contract + plan | Key scope, budget, Vault handoff, ACL replacement | Live secret render and model request | Existing | Select |
| Full browser automation | Web binding and session UI | Provider/host failures; brittle pre-release UI | High | Reject; use socket/curl and manual TUI/Web resume canaries |
| New Gherkin runner | Feature syntax only | Real shell/Nix behavior without bindings | New dependency | Reject |
| Custom session database test | Backend internals | Deployment contract | High | Reject; trust upstream persistence tests and run restore canary |

The selected seams are the fewest that catch the trust boundaries: shell
tests, targeted Nix dry-build, IaC tests/plan, and live canaries.

### Scenario-to-slice map

| Behavior scenario | First proving slice | Broader evidence |
|---|---|---|
| Reattach to eight slots | S3 | S6 observation |
| Separate state by checkout and slot | S2, completed by S3 | S5 restore |
| Refuse a second writer | S3 | S4 Web contention canary |
| Run a fresh task from the CLI | S2 | S3 two/eight-slot canaries |
| Resume a persisted conversation from the CLI | S4 | G0 pinned-TUI proof and Web fallback canary |
| Select only reviewed models from the CLI | S4 | S1 DeepSeek route/key contract and G0/S2 native Codex auth proof |
| Share native Codex authentication without sharing conversations | S2 | G0 credential lock proof and S3 two-slot canary |
| Open a slot Web surface remotely | S4 | listener inspection over SSH |
| Apply YOLO mode only inside Gemini | S2 | S4 listener proof and S6 audit |
| Inject scoped credentials without copying them into slot state | S1 and S2 | secret scan, shared-document mode/lock proof, and live route canaries |
| Recover after Gemini restart | S3 | S6 supervised restart evidence |
| Restore non-secret session state | S5 | S6 completion record |
| Keep concurrent repository edits operator-owned | S3 runbook | S6 observation |

## IP: vertical RED-GREEN slices

### G0 — pinned Harness and TUI capability gate

Before consumer edits, run the pinned `deepseek-harness-flake` package against
a temporary home and verify:

- `dsh --profile headless "..."` persists and exits;
- `dsh web --host 127.0.0.1 --no-open --port <port>` stays live;
- `--patch` and `--dump-config` expose the expected configuration rows;
- Node starts Web with the packaged `--expose-internals` fix.
- `@nexlineai/dsh-tui@0.1.1` resolves from an exact source/integrity pin,
  builds without network access, and boots as a declarative `tui` profile;
- its tests pass and a disposable PTY canary lists, resumes, and appends to a
  prior persisted session without creating a second writer;
- the native `openai-codex` catalog accepts `gpt-5.6-sol`, `gpt-5.6-terra`, and
  `gpt-5.6-luna` and persists/refreshes its OAuth record at an explicit path;
- if the pinned Harness still has no operator-facing login command, the leaf
  flake supplies one minimal one-shot `dsh-codex-login` profile over the
  upstream authorization seam;
- `/model` lists two `litellm` and three `openai-codex` choices and can select
  each without exposing another provider.

Pin the TUI in `deepseek-harness-flake`; never install it into mutable runtime
state. If the TUI gate fails, do not pin it: retain Web operationally and return
D3/S4 to planning rather than declaring CLI resume complete. If native Codex
auth/model selection fails, stop; do not substitute LiteLLM. Fix and publish a
required leaf capability before pinning it in `desktop-nixos`.

### S1 — DeepSeek Pro route, scoped provider credential, and Vault handoff

**Owner:** `homelab-iac`

**Result:** `deepseek-v4-pro` becomes a production route and one revocable
two-model key reaches an owned Vault path; Orion alone may fetch it.

- **RED:** extend the production manifest/normalized-catalog contract,
  `tests/litellm-key-contract.bats`, and Tailscale policy tests. They fail
  because the Pro alias, `deepseek-harness` key, exact two-model allowlist,
  budget, OpenBao handoff, and Orion→Discovery:8200 grant do not exist.
- **GREEN:** publish the existing `deepseek-v4-pro` OpenCode Zen catalog entry
  through the current OpenAI-compatible route, then add one key unit, one
  OpenBao KV handoff, and the narrow ACL plus deny tests. Add no provider
  abstraction and no GPT route.
- **Focused verify:** manifest/catalog contracts, Bats contracts,
  scoped model listing, `terragrunt hcl validate`, key/OpenBao plans, and full
  Tailscale policy plan.
- **Broader verify:** repository contract suite and secret scan.
- **Rollout gate:** operator accepts or replaces the USD 5 ceiling, reviews
  complete plans, then applies key/handoff before ACL.
- **Rollback:** stop the Gemini consumer, revoke the LiteLLM key, remove the
  Vault value, then remove the ACL grant. Revocation comes first on compromise.

### S2 — one persistent headless slot on Gemini

**Owner:** `desktop-nixos`

**Depends:** S1 applied

**Result:** one remote CLI task runs with declarative config and persists outside
the container root.

- **RED:** add a focused runner test that expects deterministic workspace
  identity, slot validation, `0700` home creation, the final `--patch`, secret
  injection, the split five-model catalog, telemetry opt-out, YOLO mode, and
  exact exit-status forwarding. Add Nix assertions for the host volume,
  read-only Vault render, shared `0600` OAuth document, explicit credential
  path, and backup exclusion. They fail before implementation.
- **GREEN:** import the existing DeepSeek Harness home module into Gemini; add
  the host state bind mount, narrow Vault Agent render, shared credential
  directory, immutable split-provider patch, `dsh-codex-login`, and minimal
  `dsh-headless` helper for one slot.
- **Focused verify:** runner test, config dump, and `just dry orion`.
- **Broader verify:** `just lint && just fmt-check && just docs-check`.
- **Live canary:** deploy only through `just switch-orion`; verify container,
  SSH, credential permissions, one interactive Codex login, one harmless
  DeepSeek task, one harmless native Codex task, persisted log, and no
  credential file in the shard or backup input.
- **Rollback:** switch to the prior Orion generation; leave the state volume
  untouched and revoke the LiteLLM key. On OAuth exposure, stop consumers,
  complete account-side revocation/recovery, then remove the DSH record; local
  deletion alone is not treated as revocation. Never alter `~/.codex/auth.json`.

### S3 — eight tmux slots with hard writer isolation

**Owner:** `desktop-nixos`

**Depends:** S2 live canary

**Result:** `dsh-repo` creates or attaches exactly eight independent slot
shells, and each slot permits one Harness writer.

- **RED:** shell tests create fake `dsh` and `tmux` binaries and prove: slots
  `01`–`08`, distinct homes, stable repo hash, same-name checkout separation,
  attach idempotence, mismatch refusal, invalid-slot rejection, one writer
  accepted, and a concurrent second writer rejected before fake Harness runs.
- **GREEN:** add `dsh-repo`, generalize `dsh-headless` to the current slot, and
  guard both with `flock`. Do not refactor existing `tmux-repo`.
- **Focused verify:** shell test and Home Manager package evaluation.
- **Broader verify:** lint, format, and Orion dry-build.
- **Live canary:** two slots run harmless concurrent tasks first; only then
  launch all eight with bounded read-only prompts and verify eight distinct
  session roots.
- **Rollback:** detach/stop only the new tmux session and restore the prior
  generation; never kill unrelated tmux sessions or delete state.

### S4 — CLI resume with loopback Web fallback

**Owner:** `desktop-nixos`

**Depends:** S3

**Result:** one slot can resume interactively in the terminal, switch among the
five reviewed models, or fall back to loopback Web.

- **RED:** runner tests prove `dsh-tui` uses the current shard/lock and immutable
  profile while Web uses `--host 127.0.0.1`, `--no-open`, an explicit port,
  occupied-port failure, lock contention, and credential-free argv.
- **GREEN:** add the minimal `dsh-tui` and `dsh-web` wrappers; document
  `/resume`, `/model`, SSH forwarding, the `3081`–`3088` convention, and Web
  fallback in one desktop-nixos guide.
- **Focused verify:** shell tests plus `ss` against a local disposable boot.
- **Broader verify:** docs-check and Orion dry-build.
- **Live canary:** create a harmless session, exit, resume it with `/resume`,
  switch among all five models with `/model`, prove both DeepSeek choices reach
  `litellm` and all three GPT choices reach `openai-codex`, and append one turn.
  Then repeat resume through Web, confirm only `127.0.0.1:<port>`, and verify
  lock release.
- **Rollback:** remove the TUI wrapper/profile first and use Web; stop Web and
  revert its helper if needed. No ingress, DNS, or ACL rollback exists.

### S5 — encrypted state backup and isolated restore

**Owner:** `desktop-nixos`

**Depends:** S2 state layout stable

**Result:** non-secret state is recoverable from Kepler without touching live
state.

- **RED:** Nix/test contract expects the exact source path, Kepler repository,
  retention, complete shared-credential and shard credential/tmp exclusions,
  and a restore-to-new-directory recipe.
- **GREEN:** reuse the existing Restic password, SSH key, receiver, and
  retention pattern for one Orion backup definition; add one verification
  recipe. No new backup framework or offsite tier.
- **Focused verify:** Orion dry-build and rendered unit inspection.
- **Broader verify:** lint/format plus Kepler receiver reachability.
- **Live canary:** run one backup, restore one disposable slot to a temporary
  directory, verify its session using the pinned Harness, scan for excluded
  credential files, then discard only the temporary restore.
- **Rollback:** disable the timer while retaining the encrypted repository;
  remove snapshots only through the established Restic maintenance process.

### S6 — completion and observation

**Owners:** `desktop-nixos`, `homelab-iac`, `homelab`

**Depends:** S1–S5

- Record exact package/input revisions, deployed Orion generation, scoped key
  policy, OAuth record path (never value), state/backup paths, and canary
  evidence.
- Observe eight-slot use for seven days: writer-lock and OAuth-refresh errors,
  provider/account throttling, failed backups, Gemini disk growth, and
  unexpected listeners.
- Update this proposal and `docs/proposal-index.md` together. Graduate the
  desktop guide/implementation record only after the restore and observation
  gates pass.

## Rollout order and stop conditions

Land leaf-first:

1. G0 Harness proof, exact TUI package/canary, and bounded native Codex login;
   publish the leaf flake only with the passing profiles.
2. `homelab-iac` DeepSeek Pro route, two-model key, Vault handoff, and reviewed
   ACL.
3. `desktop-nixos` one-slot persistent runner and shared OAuth document; the
   operator runs `dsh-codex-login` once.
4. Two-slot, then eight-slot tmux concurrency.
5. CLI `/resume` plus loopback Web fallback.
6. Restic backup and restore.
7. Seven-day observation and proposal closure.

Stop immediately on any of:

- two writers reach one shard;
- any credential value appears outside the owned Vault render or shared `0600`
  DSH credential document, including Git, Nix store paths, tmux environment,
  slot state, logs, or restored backup;
- Web listens on a non-loopback address;
- a package bump cannot open a copied prior session;
- the TUI pin drifts, fails its tests, cannot resume a copied session, or lists
  a model outside the five-alias allowlist;
- either DeepSeek model fails through the scoped LiteLLM key, any GPT model
  reaches LiteLLM, or any GPT model fails through native `openai-codex`;
- native Codex requires reading, copying, or modifying `~/.codex/auth.json`;
- the full Tailscale plan widens access beyond Orion→Discovery:8200;
- Orion/Gemini health, SSH, existing Herdr sessions, or unrelated backups
  regress;
- the two-slot canary corrupts state or produces unclassified provider errors.

## Acceptance criteria

- The owning `.feature` scenarios are satisfied with named runnable evidence.
- One checkout yields exactly eight stable slot homes and a reattachable tmux
  session.
- Two checkouts with the same basename do not share state.
- A second process targeting one slot fails before Harness boot.
- Headless tasks remain fresh one-shot sessions; the pinned TUI `/resume`
  continues a persisted session from SSH/tmux.
- TUI `/model` exposes exactly `deepseek-v4-flash`, `deepseek-v4-pro`,
  `gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna`: the first two route
  through `litellm`, the latter three through native `openai-codex`.
- Web fallback resumes through SSH forwarding and listens only on loopback.
- YOLO and telemetry behavior are explicit and identical across slots.
- The dedicated LiteLLM key has no administrative role and permits only the two
  DeepSeek aliases under the accepted budget.
- One shared DSH OAuth document serves all slots through its cross-process lock,
  stays outside every slot home/backup, and never imports Codex CLI auth.
- The recovery runbook treats local OAuth-record deletion as sign-out, not
  issuer-side revocation.
- Client disconnect preserves live tmux processes; host restart preserves disk
  state but makes no live-process claim.
- One encrypted backup and isolated restore pass with credential exclusions.
- `homelab-iac` tests/plans and `desktop-nixos` lint, format, docs, and Orion
  dry-build gates pass.

## Sources

- [DeepSeek Harness CLI profiles and argument handoff](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/README.md)
- [DeepSeek Harness CLI behavior](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.md)
- [DeepSeek Harness custom providers](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/providers.md)
- [Community `dsh-tui` `/resume` implementation](https://github.com/nexlineai/dsh-tui)
- [OpenAI model identifiers](https://developers.openai.com/api/docs/models)
- [OpenAI Codex authentication](https://developers.openai.com/codex/auth/)
- [DeepSeek Harness architecture and patch precedence](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md)
- [DeepSeek Harness persistence contract](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/persistence.md)
- [DeepSeek Harness local credential precedence and boundary](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/credentials/credentials-local/README.md)
- [DeepSeek Harness OAuth credential records](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/architecture/2026-08-13-credential-records-and-authorization-flows.md)
- [DeepSeek Harness sandbox modes](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/sandbox.md)
- [Gemini persistent code stack](2026-07-23-gemini-persistent-code-stack.md)
- [Vault runtime-secret ownership](../decisions/2026-06-29-vault-secrets-platform.md)
- [Repository SSOT/SRP and publish-and-pin](../decisions/2026-06-29-repo-ssot-srp.md)
