# Agent repository and worktree policy

**Status:** Implemented (2026-08-04)

## Context

Filesystem sibling scans mixed canonical repositories with linked worktrees and
caused duplicate Graphify builds. Codex and Claude Code also carried different
repository and Graphify guidance.

Homelab already has an explicit repository inventory in `repos.json`; its audit
requires each inventory symlink to resolve to a checkout with a `.git`
directory, so a linked worktree cannot silently replace an inventory target.

## Decision

1. Use an explicit repository manifest such as `repos.json` before filesystem
   discovery. In this ecosystem, `repos.json` is the sister-repository source
   of truth.
2. Put manual worktrees under the repository-local `worktrees/` directory and
   exclude that directory from Git and Graphify.
3. When no manifest exists, skip `worktrees/`, group candidates by their
   absolute `git-common-dir`, and prefer the checkout whose absolute `git-dir`
   equals its `git-common-dir`.
4. A directly targeted worktree remains valid. Build a branch-specific graph
   only when explicitly requested.
5. Tool-managed and temporary worktrees remain valid. Never move or remove
   them automatically; inspect dirty state first and use `git worktree remove`
   only after an explicit cleanup request.
6. Query an existing Graphify graph first. Treat merged graphs as discovery
   aids and verify current operational, security, and ownership claims in
   source.

## Implementation

- `homelab/.gitignore` excludes `worktrees/` and local `graphify-out/` state.
- `homelab/.graphifyignore` excludes `worktrees/`.
- `homelab/CLAUDE.md` points to `AGENTS.md`, giving Codex and Claude Code the
  same project instructions.
- `desktop-nixos/modules/dev/agent-policy.md` owns the shared global policy.
  Codex inlines it because Codex does not expand instruction-file includes;
  Claude Code receives it as `~/.claude/AGENT_POLICY.md`.

## Consequences

- Homelab automation uses the inventory instead of guessing from directory
  names.
- Full clones placed under `worktrees/` are excluded even though Git metadata
  alone cannot identify them as linked worktrees.
- Direct branch work remains possible without polluting default multi-repo
  graphs.
- Worktree lifecycle remains a human-directed Git operation; no cleanup daemon
  or new repository scanner is introduced.
