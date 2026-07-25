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

## Hosts

Current inventory from `desktop-nixos/fleet.json`:

| Host | Role | Primary IP | Tailscale IP |
|---|---|---|---|
| `archinaut` | server | `192.168.10.225` | `100.75.250.107` |
| `discovery` | server | `192.168.10.210` | `100.76.140.121` |
| `endeavour` | laptop | — | `100.107.225.13` |
| `homeassistant` | appliance | `192.168.10.115` | — |
| `kepler` | server | `192.168.10.230` | `100.94.239.46` |
| `orion` | server | `192.168.10.220` | `100.72.85.73` |
| `pathfinder` | workstation | `192.168.10.125` | `100.102.248.13` |
| `telstar` | server | — | — |
| `vanguard` | server | `163.176.206.86` | `100.90.247.79` |
| `voyager` | server | `147.15.7.254` | `100.105.38.10` |

IPs are operational inventory, not stable public endpoints. Update
`desktop-nixos` first, publish `fleet.json`, then refresh consumers here.

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
