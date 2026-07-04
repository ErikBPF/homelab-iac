# telstar A1 capture — persistent retry (running on discovery)

**Status:** RUNNING since 2026-07-04 · **Host:** discovery · **Goal:** create the
`telstar` Oracle Always-Free Ampere A1 instance the moment free-tier capacity
frees ("Out of host capacity" is intermittent in `sa-saopaulo-1`).

## What's running
- **discovery**, systemd **--user** service `telstar-get` (erik). **Linger is
  enabled** on discovery → survives reboots.
- Retries `terragrunt apply` on `oracle/compute-telstar` **every 60s for up to 7
  days**, stopping on success or a non-capacity error.
- Script: `/home/erik/telstar-get-retry.sh` on discovery (⚠️ **not in git yet** —
  copied over; formalize as `oracle/bin/telstar-get-retry.sh` if kept).
- Shape: telstar's default **2 OCPU / 12 GB** — the *scarce* A1 shape. It may
  take days, or never within 7d. (1 OCPU/6 GB lands far easier; switch the
  `OCI_OCPUS`/`OCI_MEMORY_GBS` env if you'd rather grab the box now + upgrade.)

## Controls (run on discovery; user shell is fish, so use bash -lc)
```
# status / logs (from discovery)
XDG_RUNTIME_DIR=/run/user/1000 systemctl --user status telstar-get
journalctl --user -u telstar-get -f
# stop
XDG_RUNTIME_DIR=/run/user/1000 systemctl --user stop telstar-get
# restart (after a change)
XDG_RUNTIME_DIR=/run/user/1000 systemd-run --user --unit=telstar-get --collect \
  bash /home/erik/telstar-get-retry.sh
```
From the laptop: `ssh -p 2222 erik@<discovery> 'bash -lc "journalctl --user -u telstar-get --no-pager | tail"'`.

## On success
The apply prints `public_ip`. Then (per `compute-telstar/terragrunt.hcl`):
1. Set `hosts.telstar.ip` in `desktop-nixos/modules/meta.nix`, regenerate
   (`just fleet-json`).
2. `just deploy-telstar` (nixos-anywhere converts the Ubuntu A1 → NixOS).

## How it authenticates (the fiddly bits, for future me)
- Creds live in `homelab-iac/.env.sops` (dotenv-sops). Committed 2026-07-04
  (`10b388e`) so discovery — a sops recipient — can decrypt them.
- Script decrypts via `sops -d --input-type dotenv` (exec-env can't set the
  input-type, and the `.sops` extension isn't auto-detected as dotenv).
- Parse splits on the **first `=`** with `${line#*=}` — **not** `IFS='=' read`,
  which eats the trailing `=` base64 padding off `OCI_private_key_b64`.
- MinIO S3 state backend needs `AWS_ACCESS_KEY_ID/SECRET`, mapped from
  `MINIO_TFSTATE_ROOT_USER/PASSWORD`.
- `TG_TF_PATH=tofu`; discovery's tofu is a **tenv** shim, so `TENV_AUTO_INSTALL=true`.
- SSH pubkey injected into telstar = the laptop's `id_ed25519.pub` (copied to
  discovery as `~/telstar-ssh-key.pub`; a pubkey is not secret) so the deploy
  host can reach it.

## Follow-ups
- Make this **declarative** (a NixOS systemd service/timer on discovery in
  desktop-nixos, creds via discovery's sops) instead of the hand-placed script.
- Once telstar exists, the same 2/12-capacity chase applies to any resize; see
  `oracle/bin/upgrade-retry.sh`.
