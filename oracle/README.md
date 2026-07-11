# oracle — Always-Free offsite Oracle Cloud hosts (`voyager`, `telstar`)

Two Always-Free OCI hosts, each its own Terragrunt unit (own state) over a shared
instance module: VCN + subnet + internet gateway + route table + security list +
instance (+ a free-tier budget guard). Both boot Ubuntu as the install
entrypoint; `desktop-nixos` then converts them to NixOS via nixos-anywhere.

- **voyager** — x86 `VM.Standard.E2.1.Micro` (Always-Free x86, 1 GB). The fleet's
  offsite backup / DR anchor. A1 capacity in `sa-saopaulo-1` was too scarce, so
  voyager settled on the always-available **x86 micro** — no A1 / shape upgrade.
- **telstar** — Ampere **A1** (aarch64, default **2 OCPU / 12 GB**) for exposing
  personal projects to the public internet. A1 capacity is intermittent; a retry
  loop drives the create until it frees.

## Layout
- `root.hcl` — `oci` provider (creds from `.env.sops`) + pbkdf2 state encryption,
  MinIO S3 backend (shared `backend.hcl`).
- `modules/instance/` — network + instance + free-tier budget guard.
- `compute/` — the **voyager** unit (x86 micro).
- `compute-telstar/` — the **telstar** unit (A1).
- `bin/telstar-get-retry.sh` — loops `terragrunt apply` for telstar until A1
  capacity frees. Runs persistently on **discovery** — see
  `telstar-capture-status.md`.
- `bin/upgrade-retry.sh` — loops an in-place A1 **shape resize** until capacity
  frees (only relevant to an A1 host, e.g. resizing telstar 1/6 → 2/12).

## Secrets (`.env.sops`)
`OCI_tenancy_ocid`, `OCI_user_ocid`, `OCI_fingerprint`, `OCI_private_key_b64`
(base64 of the API signing-key PEM), `OCI_region`, `OCI_compartment_ocid`.
Optional: `OCI_availability_domain`, `OCI_SSH_PUBKEY_FILE`, shape knobs
`OCI_OCPUS` / `OCI_MEMORY_GBS`. Also `MINIO_TFSTATE_ROOT_USER` / `_PASSWORD`
(S3 backend, mapped to `AWS_*`) and `UNIFI_STATE_PASSPHRASE` (state encryption).
NetBird public relay (voyager only, default off — see `netbird/`):
`OCI_RESERVE_PUBLIC_IP` / `OCI_RELAY_PUBLIC_SURFACE` (each `"true"`/`"false"`).

## Apply
```
cd oracle/compute            # voyager (x86)   —   or oracle/compute-telstar (A1)
terragrunt apply             # via direnv (devenv provides tofu/terragrunt)
```
Take the output `public_ip` → set `hosts.<host>.ip` in
`desktop-nixos/modules/meta.nix`, run `just fleet-json` → `just deploy-<host>`.

## A1 capacity (telstar only)
`sa-saopaulo-1` has a single AD and free A1 capacity is intermittent
("500-InternalError, Out of host capacity"). The network always lands; only the
instance waits. `bin/telstar-get-retry.sh` retries `apply` until it frees
(running persistently on discovery). Smaller shapes land far more easily
(1 OCPU / 6 GB) if you'd rather grab the box then resize via
`bin/upgrade-retry.sh` — the free A1 pool is **4 OCPU / 24 GB** total.
