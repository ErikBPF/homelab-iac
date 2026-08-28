# telstar A1 capture — cutover complete

**Status:** CREATED AND CUT OVER 2026-08-20 · **Host:** discovery · **Result:**
`telstar` runs NixOS on Oracle Always-Free Ampere A1.

## Acquisition runner (stopped)
- **discovery**, systemd **--user** service `telstar-get` (erik), is inactive
  with result `success`; creation ended the retry loop.
- Source: `oracle/bin/telstar-get-retry.sh`; deployed copy:
  `/home/erik/telstar-get-retry.sh` on discovery.
- Acquired shape: **2 OCPU / 12 GB** A1 Flex.

## Re-arm controls (run on discovery only after a reviewed recreate/resize plan)
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

## Completed cutover
1. Applied temporary `/32` bootstrap/recovery ingress on TCP/22 and TCP/2222.
2. Added Telstar's public and Tailscale addresses to the fleet metadata.
3. Converted Ubuntu to NixOS, then deployed the corrected `enp0s6` DHCP config.
4. **Mandatory reversal completed 2026-08-20:** applied Voyager normally and
   restored the diagnostic console connection to Vanguard.
5. Verified public TCP/22 and TCP/2222 are closed; fleet SSH on tailnet TCP/2222,
   clean-boot DHCP, and Tailscale autoconnect are healthy.

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
