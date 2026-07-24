# homelab

Private coordination hub for the homelab repository ecosystem.

This repo owns cross-repository decisions, inventory, audits, and delegation.
Component code, configuration, tests, and deployment logic remain in their
own repositories.

## Model

| Layer | Owner |
|---|---|
| Network and declarative external/platform control planes | `homelab-iac` |
| Host OS, fleet facts, and cluster substrate | `desktop-nixos` |
| Household workloads | `servarr` |
| Lab workloads | `homelab-gitops` |
| Application, device, package, and content concerns | Their component repos |

`desktop-nixos` publishes `fleet.json`. Consumers vendor a deliberate snapshot;
`just fleet-drift` reports drift and `just fleet-update` refreshes both copies.

## Commands

```bash
just status
just audit
just fleet-drift
just fleet-update
just test
```

Local working trees are available through gitignored symlinks under
`references/repos/`. [`repos.json`](repos.json) is the repository inventory.
Architecture records live under [`docs/`](docs/README.md).
