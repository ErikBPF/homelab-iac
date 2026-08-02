# Gemini persistent code stack

**Status:** Proposed — exploration complete; no configuration or deployment approved

## 1. Goal

Make `gemini` the remote-primary development machine:

- code, editors, shells, dev servers, and coding agents run on Gemini;
- one persistent Herdr session survives client disconnects;
- laptop, Pathfinder, and Endeavour can detach and reattach over SSH;
- Neovim runs in ordinary Herdr panes beside Claude Code, Codex, OpenCode,
  Gemini CLI, and Hermes Agent;
- the entry path is short enough to become the default workflow.

“Persistent forever” means **while the Gemini container and Herdr server stay
alive**. Detach preserves live processes. A Herdr server/container restart
restores layout and supported agent conversations, but it cannot resurrect an
arbitrary shell, Neovim, test, or dev-server process.

## 2. Existing foundation

Most of the stack already exists:

- Gemini is the NixOS container on Orion, reachable through tailnet MagicDNS on
  SSH port 2222.
- `nvim`, `herdr`, `tmux`, Claude Code, Codex, OpenCode, Gemini CLI, and the
  Hermes client are already installed there.
- project trees are remote-primary on Gemini and mirrored to the laptop by
  Syncthing.
- the shared SSH module already defines `Host gemini`.
- `snix`, `sdp`, `sspark`, `sair`, and `scon` currently SSH to the right project
  directory, but each lands in an ephemeral login shell.
- Herdr already has launch keys for Claude Code, Codex, OpenCode, and Hermes,
  with `session.resume_agents_on_restore = true`.
- the same fleet user public key is authorized on Gemini and normal fleet
  hosts. Access from all three clients still needs an explicit pre-rollout
  check that their private key/agent and tailnet route are available.

The missing part is therefore an idempotent session entry point, current native
integrations, and a documented ownership model—not another terminal stack.

## 3. Decision

### 3.1 One outer multiplexer: Herdr

Run one **named Herdr server**, `code`, on Gemini:

```text
Gemini
└── Herdr session: code
    ├── workspace: desktop-nixos
    │   ├── nvim .
    │   ├── coding agent
    │   └── shell/test/server
    ├── workspace: dataplatform
    ├── workspace: dataplatform-spark
    ├── workspace: dataplatform-airflow
    └── workspace: dataplatform-datacontracts
```

Use one workspace per repository. Tabs separate concerns within a repository;
panes hold the editor, agent, shell, test watcher, or dev server.

Herdr supports named sessions and remote named attach:

```bash
herdr --remote gemini --session code
```

The local Herdr process is only a thin client. Work, credentials, PTYs, and
session state remain on Gemini. Normal SSH followed by
`herdr session attach code` remains the universal fallback.

### 3.2 Neovim is a pane, not a service

Start `nvim .` once in each repository workspace and detach from Herdr when
leaving. No `nvim --server`, remote RPC bridge, nested terminal protocol, or
editor-specific daemon is needed.

This preserves the exact terminal editor from every client and avoids separate
Neovim session ownership. Unsaved buffers are only as durable as the live
Neovim process; normal swap/undo files remain the crash-recovery mechanism.

### 3.3 tmux is break-glass only

Do not nest tmux inside Herdr. Both own prefixes, panes, resizing, scrollback,
and persistence; nesting makes the common path worse.

Keep the existing declarative tmux installation for:

- emergency work while Herdr is unavailable;
- an independent long-running non-agent session when Herdr itself is under
  maintenance;
- diagnosing Herdr without running the diagnosis inside Herdr.

No resurrect/continuum plugins. Gemini/container availability is not solved by
serializing tmux layouts.

### 3.4 One active driver

Laptop, Pathfinder, and Endeavour may all attach, but the workflow assumes one
interactive driver at a time. Herdr direct terminal attach explicitly grants
input and resize ownership to one client; `--takeover` transfers it. Read-only
observers are available through the terminal-session observer API when Hermes
or automation only needs output.

This avoids simultaneous resize/input races and accidental keystrokes from a
second device.

## 4. Herdr integrations

The flake currently pins Herdr `v0.7.1`; upstream documentation currently marks
`0.7.5` as latest. Bump the pinned release first, then install integrations
declaratively and verify their reported versions.

Required:

| Agent | Integration value |
|---|---|
| Claude Code | native session identity; restart resumes with `claude --resume` |
| Codex | native session identity; restart resumes with `codex resume` |
| OpenCode | lifecycle state plus native session identity |
| Hermes Agent | lifecycle/tool/approval state plus native session identity |

Gemini CLI is detected as an agent and can be started through Herdr automation,
but upstream does not currently list a native Gemini session-restore
integration. Treat it like an ordinary live process: detach is safe; a Herdr
server restart may lose that conversation.

The imperative commands are useful for discovery:

```bash
herdr integration install claude
herdr integration install codex
herdr integration install opencode
herdr integration install hermes
herdr integration status
```

They are **not** the final deployment mechanism because they mutate agent
configuration under `$HOME`. Model their generated hook/plugin files in the
owning Home Manager modules, or add supported integration options in the leaf
flakes (`codex-flake`, `opencode-flake`, `hermes-flake`) before consuming them
here. Do not run an activation script that rewrites Nix-owned configuration on
every switch.

Hermes has two useful roles:

1. an interactive `hermes` pane inside the `code` session, restored through the
   native integration;
2. an automation/controller client using Herdr's CLI/socket surface to list
   agents, read recent output, submit a prompt, wait for lifecycle state, or
   observe a terminal.

Start with role 1. Add role 2 only for a concrete Hermes skill; do not build a
second session orchestrator before a workflow needs it. Alternate-screen TUIs
have limited readable scrollback, so automation should prefer lifecycle state
and agent transcripts over scraping rendered terminal output.

## 5. Session history: centralize, do not sync

Session history follows the execution host. Because all three agents run on
Gemini, Gemini is the sole writer and source of truth:

| Agent | Gemini state | Supported continuation |
|---|---|---|
| Codex | local state under `~/.codex` | `codex resume` / Herdr native restore |
| Claude Code | project-scoped JSONL under `~/.claude/projects/` | `claude --resume` / Herdr native restore |
| OpenCode | SQLite under `~/.local/share/opencode/` | session picker / Herdr native restore |

Laptop, Pathfinder, and Endeavour do not need copies of these directories:
they attach to the same Gemini processes through Herdr. Starting an agent
locally intentionally creates an independent local history.

Do **not** add `~/.codex`, `~/.claude`, or `~/.local/share/opencode` to
Syncthing:

- Codex and OpenCode contain live SQLite databases with WAL/SHM files; file
  replication is not database replication and can produce inconsistent state;
- Claude transcripts are continuously appended JSONL; concurrent writers can
  interleave, and its internal entry format is explicitly unstable;
- all three trees mix session state with logs, caches, configuration, plugins,
  and credentials such as `auth.json`;
- bidirectional conflict resolution has no semantic way to merge two
  conversations.

For a one-time migration into Gemini:

- Codex: finish local sessions and keep the old machine as a read-only archive;
  resume/export important results into repository docs. Do not copy the whole
  live `CODEX_HOME` because it also contains authentication and mutable
  databases.
- Claude Code: use `/export` for human-readable records. Copying raw JSONL is
  only a cold migration while Claude is stopped, with identical repository
  paths; it is not the normal workflow.
- OpenCode: use the supported `opencode export <session-id>` and
  `opencode import <file>` commands. Use `--sanitize` when the export leaves the
  trusted Gemini boundary.

Back up Gemini session history as a **single-writer cold snapshot**, not as a
multi-machine working copy. The backup must exclude credentials and may require
stopping/quiescing agents and checkpointing SQLite first. Session history is
convenience state; durable decisions, commands, and handoff context still belong
in the repository (`AGENTS.md`, RFCs, ADRs, behavior artifacts, and commits).

## 6. Entry points and aliases

Add one canonical alias to the shared alias module:

```nix
hg = "herdr --remote gemini --session code";
```

Keep a server-side fallback:

```nix
hgs = "ssh -t gemini 'exec herdr session attach code'";
```

`hg` is the daily path from laptop, Pathfinder, and Endeavour. It preserves
local keybindings and local clipboard bridging. `hgs` proves that the server
session itself works and supports clients where remote attach is unavailable.

Keep the existing `s*` project aliases as one-off plain shells during rollout.
After the Herdr flow is proven, either delete them or retain only aliases that
still serve a distinct non-Herdr use. Do not create five Herdr aliases: workspace
navigation already selects the repository.

## 7. Session bootstrap

Bootstrap once, interactively:

1. attach with `hg`;
2. create the five repository workspaces at their existing Gemini paths;
3. open `nvim .` and any long-running shells/agents needed in each workspace;
4. detach with `Ctrl-b q`;
5. reattach from another client and confirm the same live processes.

Do not encode the initial pane layout in Nix. Herdr persists the layout itself;
a declarative layout generator would duplicate its state model. Automate
workspace creation later only if rebuilding the layout becomes frequent.

## 8. Failure and recovery model

| Event | Expected result |
|---|---|
| SSH/Wi-Fi/client closes | all Gemini processes continue |
| attach from another client | same named Herdr session |
| Herdr client version changes | normal remote attach may restart the server; use compatible pinned clients and test before rollout |
| Herdr server restarts | layout returns; integrated agents resume; shells, Neovim, tests, and servers restart as fresh shells |
| Gemini container restarts | same as server restart; repository files remain |
| Orion is down | stack unavailable; Syncthing mirror is offline fallback, not a second writable primary |

Do not enable pane-history persistence initially. It can store prompts, command
output, tokens, and secrets in Herdr session files. Agent-native transcripts and
Neovim recovery cover the useful cases with less secret duplication.

## 9. Rollout

### Phase 0 — compatibility probe

- bump Herdr from `0.7.1` to a reviewed current release;
- build Gemini and all three client hosts with the same pinned Herdr version;
- verify plain `ssh gemini` from laptop, Pathfinder, and Endeavour;
- verify `herdr --remote gemini --session code` from each client;
- inspect `herdr integration status`.

Stop if remote attach replaces a live server instead of attaching compatibly.
Do not use experimental `--handoff` as the normal path.

### Phase 1 — declarative integrations and aliases

- declare the four hook/plugin integrations at their configuration owners;
- add `hg` and `hgs`;
- run the normal lint/fmt gates;
- dry-build Orion, laptop, Pathfinder, and Endeavour.

### Phase 2 — live workflow proof

- switch Orion first, then the three clients;
- create the `code` session and repository workspaces;
- leave one Neovim pane, one agent pane, and one long-running shell command;
- detach and reattach from every client;
- restart only a disposable test agent to prove native conversation restore;
- verify no agent config drift and no plaintext secrets were introduced.

### Phase 3 — simplify

After one week of use, remove redundant `s*` aliases only if `hg` fully replaces
them. Keep tmux installed unless a later audit shows no break-glass value.

## 10. Acceptance criteria

- `hg` from all three clients opens the same Gemini `code` session.
- Disconnecting every client leaves Neovim and agent processes running.
- Only one client controls a directly attached terminal; takeover is explicit.
- Claude Code, Codex, OpenCode, and Hermes report current integrations and
  restore a disposable conversation after a Herdr server restart.
- Gemini CLI is documented as live-detach persistence only.
- no nested tmux in the normal path;
- no persisted pane history;
- no Syncthing replication of agent state directories;
- no new service, daemon, custom wrapper, or layout generator;
- `just lint && just fmt-check` and `just dry orion`, `just dry laptop`,
  `just dry pathfinder`, and `just dry endeavour` pass;
- after switching Orion, SSH and the Gemini container/Herdr session are checked
  live before calling rollout complete.

## 11. Sources

- [Codex manual: configuration and local state](https://developers.openai.com/codex/codex-manual.md)
- [Claude Code: session storage and export](https://code.claude.com/docs/en/sessions)
- [OpenCode CLI: session export and import](https://opencode.ai/docs/cli/)
- [Herdr: persistence and remote access](https://herdr.dev/docs/persistence-remote/)
- [Herdr: session state and restore](https://herdr.dev/docs/session-state/)
- [Herdr: official agent integrations](https://herdr.dev/docs/integrations/)
- [Herdr: agent automation](https://herdr.dev/docs/agent-automation/)
- [Existing Gemini sandbox record](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-10-orion-dev-sandbox-microvm.md)
- [Existing terminal tooling record](https://github.com/ErikBPF/desktop-nixos/blob/main/docs/implemented/2026-07-10-terminal-tooling-additions.md)
