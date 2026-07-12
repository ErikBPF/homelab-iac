# PocketID NetBird client — import runbook (human, one-time)

**Status:** scaffold (code-only — not applied). Source of truth is
`terragrunt.hcl` in this directory. Goal: adopt the EXISTING NetBird OIDC client
into Terraform without re-issuing it (G2 = import), so PocketID admin becomes
declarative while the netbird dashboard SSO stays deferred (upstream bug).

## Prereqs (Phase S)

1. Mint a PocketID API token: log into `https://id.homelab.pastelariadev.com`
   with the passkey → Settings → API Keys → create. (The PocketID admin UI
   works; only the netbird dashboard SSO is broken.)
2. Store it in this repo's sops-managed env, via **`rtk proxy sops`** only
   (never bare `sops` — it truncates):

   ```
   rtk proxy sops set .env.sops '["POCKETID_API_TOKEN"]' '"<token>"' --input-type dotenv
   rtk proxy sops set .env.sops '["POCKETID_BASE_URL"]' '"https://id.homelab.pastelariadev.com"' --input-type dotenv
   ```

   Verify the key count went up by exactly the number you added
   (`rtk proxy sops -d --input-type dotenv .env.sops | grep -c '^POCKETID'`),
   then re-run direnv so `.env` picks them up.

## Import + verify (from a wired LAN host on the tailnet)

```
cd pocketid/clients
terragrunt init
terragrunt import 'pocketid_client.this["netbird"]' 579d2f64-2bd0-4c5d-9796-f5a4ba2268d0
terragrunt plan          # MUST print "No changes"
```

If `plan` shows a diff (most likely on `callback_urls` or `logout_callback_urls`):
the **live client is the source of truth**. Update the `clients."netbird"` map
in `terragrunt.hcl` to match the live values, re-plan until clean, THEN apply.
Never apply a diff you did not intend — a wrong `callback_urls` breaks
`netbird up` and the dashboard redirect at once.

## What this manages

- `pocketid_client.this["netbird"]` — public + PKCE, `client_id` pinned to
  `579d2f64-2bd0-4c5d-9796-f5a4ba2268d0`, callbacks = dashboard `/` + CLI
  loopback `:53000`.

Nothing else in PocketID is managed here yet (users/groups stay manual until
group-based ACLs are wired — RFC §3, optional).
