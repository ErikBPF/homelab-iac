# Disaster recovery — OpenTofu state

How to recover the Terragrunt state for this repo if MinIO or the whole
`discovery` host is lost. Read this *before* you need it.

## What the state is, and where the copies live

State is stored in the **MinIO bucket `tofu-state`** on `discovery`
(container `minio-tfstate`, data on `discovery:/var/lib/minio-tfstate/data`),
reached at `https://minio-tfstate.homelab.pastelariadev.com`. On top of the
backend, OpenTofu encrypts every state/plan file (PBKDF2 + AES-GCM,
`UNIFI_STATE_PASSPHRASE`), so **every copy below is ciphertext** — safe to hold
on any host, useless without the passphrase.

| Copy | Location | Notes |
|---|---|---|
| **Authoritative** | MinIO bucket `tofu-state` on discovery (sda2) | versioned bucket |
| On-disk mirror | `discovery:/home/erik/tofu-state-export` | `minio-tfstate-mirror` container, `mc mirror --watch` |
| Off-host #1 | `orion:/home/erik/tofu-state-backup` | Syncthing, 30-day staggered versioning |
| Off-host #2 | `kepler:/home/erik/tofu-state-backup` | Syncthing, 30-day staggered versioning |
| Versioned snapshots | `discovery:/home/erik/vault/restic/tofu-state` (sdb) | restic, daily 06:30, 7d/4w/6m |

Key layout in every copy: `<component>/<unit>/terraform.tfstate`, e.g.
`unifi/environments/home/network/terraform.tfstate`,
`cloudflare/dns/terraform.tfstate`.

## Secrets you must not lose

Everything except the age key is **git-committed but age-encrypted**, so it is
recoverable *iff* the age key survives:

- **sops age key** — `~/.config/sops/age/keys.txt` (authoritative on the
  laptop; staged onto each host during `just deploy`). **This is the single
  point of total loss.** It decrypts `secrets.yaml` (restic password) and
  `homelab-iac/.env.sops` (`UNIFI_STATE_PASSPHRASE`, MinIO creds). It is **not**
  in Syncthing or any repo. → **Back it up off-fleet** (password manager /
  offline media). If it survives, everything below is recoverable.
- `UNIFI_STATE_PASSPHRASE` — decrypts the tofu state. Lives in
  `homelab-iac/.env.sops` (committed). Lose it *and* the age key → state is
  permanently unreadable; only path left is re-import from live infra.
- `restic_tofu_state_password` — `desktop-nixos/secrets/sops/secrets.yaml`
  (committed). Lose it → the restic repo is unreadable (the other copies still
  work).
- `MINIO_TFSTATE_ROOT_USER` / `_PASSWORD` — `homelab-iac/.env.sops` (committed).

## Scenario A — a state object is lost/corrupt, MinIO is alive

Restore the one ciphertext file from any off-host copy into the bucket:

```bash
# from a host with mc + bucket creds (or via the discovery mirror container)
mc cp orion:/home/erik/tofu-state-backup/<component>/<unit>/terraform.tfstate \
      tf/tofu-state/<component>/<unit>/terraform.tfstate
# verify
cd <component>/<unit> && terragrunt plan   # expect: No changes
```

(`mc mirror --watch` will re-pull from the bucket, so fix the bucket, not the
export dir.) restic alternative: `restic-tofu-state restore latest --target /tmp/r`
then copy the file out of `/tmp/r/home/erik/tofu-state-export/...`.

## Scenario B — discovery is gone (MinIO with it)

State survives on orion + kepler (Syncthing). Recover without waiting for a new
MinIO by temporarily using a **local** backend:

```bash
# 1. grab the latest ciphertext from a surviving peer
rsync -a orion:/home/erik/tofu-state-backup/ ./recovered-state/

# 2. per unit, point at local state instead of s3 (edit backend.hcl's read or
#    override remote_state to backend="local"), drop the recovered file in, then:
cd <component>/<unit>
terragrunt init            # local backend
terragrunt plan            # No changes  (needs UNIFI_STATE_PASSPHRASE + provider creds)
```

To restore the *normal* topology: stand `minio-tfstate` back up (servarr
`infra.yml` on the new discovery), `mc mb tf/tofu-state`, `mc cp` the recovered
files to their keys, revert `backend.hcl` to s3, `terragrunt init -migrate-state`.

## Scenario C — total loss (no usable backup, age key gone)

The live infrastructure is the source of truth. Re-import from scratch per the
README "Phase 1 — import current state": `terragrunt import` each resource,
`plan` to zero-diff. Tedious but always possible — nothing here is irreplaceable
*except* convenience.

## Rehearse it

DR that has never been run is a guess. Once: copy a peer's
`tofu-state-backup/cloudflare/dns/terraform.tfstate` to a scratch dir, point a
throwaway checkout at it with a local backend, and confirm `plan` is no-diff.
That proves the ciphertext + passphrase + provider creds all still line up.
