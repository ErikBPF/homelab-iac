# Fleet CI notifications in Slack

**Status:** Ready for Slack/GitHub App connection
**Date:** 2026-07-24

## Decision

Use one Slack channel, `#ci`, with the official GitHub integration. Do not add
incoming-webhook steps to every repository: the integration already provides
workflow start/completion threads, reruns, approvals, and workflow filters.

Subscribe only the primary CI workflow for pull requests and `main`. Security
and deployment messages remain in Discord.

## Activation

Install the GitHub app for Slack, invite `@github` to `#ci`, sign in, then run
these commands in that channel:

```text
/github subscribe ErikBPF/desktop-nixos workflows:{name:"Check" event:"pull_request","push" branch:"main"}
/github subscribe ErikBPF/homelab-iac workflows:{name:"ci" event:"pull_request","push" branch:"main"}
/github subscribe ErikBPF/servarr workflows:{name:"Validate" event:"pull_request","push" branch:"main"}
/github subscribe ErikBPF/homelab-gitops workflows:{name:"validate" event:"pull_request","push" branch:"main"}
/github subscribe ErikBPF/hermes-flake workflows:{name:"build" event:"pull_request","push" branch:"main"}
/github subscribe ErikBPF/hermes-skills workflows:{name:"Validate skills" event:"pull_request" branch:"main"}
/github subscribe ErikBPF/home-assistant-config workflows:{name:"Validate HA config" event:"pull_request","push" branch:"main"}
/github subscribe ErikBPF/klipper-biqu workflows:{name:"Validate" event:"pull_request" branch:"main"}
/github subscribe ErikBPF/kindle-dash workflows:{name:"CI" event:"pull_request","push" branch:"main"}
/github subscribe ErikBPF/opencode-flake workflows:{name:"check" event:"pull_request","push" branch:"main"}
/github subscribe ErikBPF/codex-flake workflows:{name:"check" event:"pull_request","push" branch:"main"}
```

Verify configuration with:

```text
/github subscribe list features
```

`ha-harness` and `cosmo-notes` now have private GitHub remotes, but no
primary CI workflows suitable for `#ci`. Do not subscribe their security-only
workflows; add filtered subscriptions when normal CI exists.

## Noise gate

Do not subscribe to unfiltered `workflows`, commits, issues, comments, or
security workflows. Reassess after 30 days; remove any workflow that produces
messages without operator action.
