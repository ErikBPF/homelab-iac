# NetBird default-deny policy — hand-readable export

**Status:** scaffold (WP4, code-only — not applied). Source of truth is
`terragrunt.hcl` in this directory; this file is a belt-and-suspenders
human-readable mirror (RFC §8 grill #13) — if Terraform state is ever lost,
this doc is enough to recreate the *intent* by hand in the NetBird dashboard
without silently leaving the mesh open.

Cross-ref:
[`docs/proposals/2026-07-10-netbird-selfhosted-overlay.md`](../../../../desktop-nixos/docs/proposals/2026-07-10-netbird-selfhosted-overlay.md)
§6/§8 (from the `desktop-nixos` repo — relative path may not resolve from
every checkout; see that repo directly).

## Baseline stance

NetBird denies traffic between any two peers unless an explicit **policy
rule** accepts it. There is no "create a deny rule" resource — deny is what
happens when nothing accepts. This baseline defines exactly **one** accept
rule; everything else is denied by omission.

**Operational caveat (do this by hand, Phase O):** a freshly bootstrapped
NetBird account ships an implicit **"Default" policy** that allows *all*
peers to reach each other. The Terraform provider does not manage that
built-in resource — an admin must disable or delete it in the
dashboard/API after control-plane bootstrap (WP2), otherwise it coexists
with (and defeats) everything below.

## Groups (`netbird/groups`)

| Group | Purpose | Membership at scaffold time |
|---|---|---|
| `admins` | Interactive admin devices | empty — populate with laptop/pathfinder/galaxy peer IDs once enrolled |
| `fleet-servers` | Always-on fleet hosts, enrolled via setup key | empty |
| `fleet-clients` | Interactive user devices, enrolled via PocketID SSO | empty |
| `netbird-relays` | discovery relay#1 + voyager relay#2 (+ relay#3, RFC §4a) | empty |

## Policies (`netbird/policies`)

| Policy | Rule | Action | Source | Destination | Protocol/Ports | Bidirectional |
|---|---|---|---|---|---|---|
| `admin-ssh` | `admins-ssh-everywhere` | accept | `admins` | `fleet-servers`, `fleet-clients`, `netbird-relays` | tcp/2222 | no |

No other rule exists. No other policy exists. Any peer pair not covered by
the row above cannot reach each other over the NetBird overlay.

## Posture checks (`netbird/posture-checks`)

| Check | Requirement |
|---|---|
| `min-netbird-client` | NetBird client >= `0.30.0` (placeholder — sync to whatever `desktop-nixos` WP1's `netbird-client` module pins) |

Not yet attached to any policy's `source_posture_checks` (WP4 scaffold only —
wire it in once real peers exist to test against).

## Setup keys (`netbird/setup-keys`)

| Key | Type | Expiry | Usage limit | Auto-groups |
|---|---|---|---|---|
| `fleet-server-bootstrap` | reusable | 7 days | 5 (placeholder — size to real host count) | `fleet-servers` |

Machine enrollment bypasses user MFA by design (RFC §6a) — kept ephemeral,
usage-limited, and group-scoped on purpose; never make this a standing,
unlimited-use key.
