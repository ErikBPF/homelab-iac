# NetBird + PocketID declarative admin — apply runbook (human, one-time)

**Status:** scaffold (code-only — nothing applied). Implements RFC
`desktop-nixos/docs/proposals/2026-07-11-netbird-terraform-declarative-admin.md`
§8. `tofu/terragrunt apply` is **human-run, from a wired LAN host joined to the
tailnet** (the control-plane endpoints `nb.<zone>` / `id.<zone>` are tailnet-only;
a Wi-Fi apply can self-lock the network stack — repo convention).

The control plane is **already LIVE** on discovery and the overlay is proven via
CLI (`netbird up`). This makes the *administration* declarative so the broken
netbird dashboard is never on the critical path.

This repo has **no cross-stack `dependency` blocks** (same as `unifi/`): each unit
is applied in order and real IDs are pasted forward from the previous unit's
output. The `TODO-paste-group-id-…` placeholders below are that handoff.

## 0. Bootstrap tokens → sops (Phase S)

Both providers need an API token; the netbird dashboard that would normally mint
one is the broken thing, but the **PocketID admin UI and the netbird mgmt API
both work**. Store both via **`rtk proxy sops`** only (bare `sops` truncates —
verify the key count after each set).

- **PocketID token:** log into `https://id.homelab.pastelariadev.com` (passkey)
  → Settings → API Keys → create.
- **NetBird PAT:** mint via the mgmt REST API with a `netbird` CLI OIDC token
  (confirm the exact path against mgmt 0.74.3 at wire-up):

  ```
  # get your user id + a bearer token from a CLI login, then:
  curl -sS -X POST https://nb.homelab.pastelariadev.com/api/users/{userId}/tokens \
    -H "Authorization: Bearer <oidc-access-token>" \
    -H 'Content-Type: application/json' \
    -d '{"name":"terraform","expires_in":365}'
  ```

  ```
  rtk proxy sops set .env.sops '["NETBIRD_TOKEN"]'        '"<pat>"'   --input-type dotenv
  rtk proxy sops set .env.sops '["POCKETID_API_TOKEN"]'   '"<token>"' --input-type dotenv
  # (management/base URLs default in each root.hcl; add only if they change)
  ```

  Re-run `direnv reload` so `.env` picks them up.

## 1. PocketID — import the NetBird OIDC client (G2)

See `../pocketid/clients/IMPORT.md`. In short:

```
cd pocketid/clients && terragrunt init
terragrunt import 'pocketid_client.this["netbird"]' 579d2f64-2bd0-4c5d-9796-f5a4ba2268d0
terragrunt plan          # MUST be "No changes" — reconcile the map if not
terragrunt apply
```

## 2. NetBird — groups, then everything that references them

```
cd netbird/groups        && terragrunt apply && terragrunt output group_ids
```

Paste the real IDs from that output into the `group_ids` locals of:
`netbird/policies`, `netbird/setup-keys`, `netbird/nameservers` (and `routes`
when used). Then:

```
cd netbird/posture-checks && terragrunt apply && terragrunt output posture_check_ids
cd netbird/policies        && terragrunt apply   # default-deny + admin-ssh allow
cd netbird/nameservers     && terragrunt apply   # split-DNS *.homelab
cd netbird/setup-keys      && terragrunt apply && terragrunt output   # -> fleet-server key
```

**By hand (provider does not manage it):** disable/delete the implicit **"Default"
allow-all policy** in the netbird API/UI, or it defeats the default-deny set
(see `policies/DEFAULT-DENY.md`).

## 3. Managed peers (RFC §8.5)

1. Copy the setup key from step 2's `setup-keys` output into **desktop-nixos**
   sops as `netbird/setup_key` (via `rtk proxy sops` on that repo's
   `secrets/sops/secrets.yaml`; the `netbird-client.nix` module reads it).
2. Flip `modules.networking.netbird-client.enable = true` on the target host(s)
   in desktop-nixos (start 1–2, e.g. laptop + one LAN server), then
   `just deploy <host> <ip> 2222`.
3. Verify on the peer: `netbird status` → Management/Signal Connected, relay
   available, and it lands in `fleet-servers` (setup-key `auto_groups`).

## 4. CIDR → 10.100/16 (G4, RFC §5)

The fleet fact is already `10.100.0.0/16` (desktop-nixos `fleet.netbird`), but
live peers get netbird's default CGNAT `100.110.0.0/16` (verified: the torn-down
ad-hoc laptop peer was `100.110.244.80/16`). The `netbirdio/netbird` 0.0.9
provider exposes **no account-settings/peer-range resource**, so this is a mgmt
**API step, not Terraform**. Probe first:

```
curl -sS -H "Authorization: Token $NETBIRD_TOKEN" \
  https://nb.homelab.pastelariadev.com/api/accounts | jq '.[0].settings'
```

If a writable network-range field exists, PUT it to `10.100.0.0/16` and re-up
peers. If not, the range is a management default — since the account is fresh
(only throwaway peers), accept `100.110/16` for now or recreate the account
before enrolling real peers. **Decide, then record the outcome here.**

## 5. Routes — deferred

`netbird/routes` is an empty scaffold. Filling it (expose 192.168.10.0/24 to
remote peers so split-DNS resolves off-LAN) needs a LAN routing peer + an
explicit expose decision — see `routes/terragrunt.hcl`.
