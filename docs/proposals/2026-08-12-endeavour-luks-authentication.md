# Endeavour LUKS authentication and convenience unlock

**Status:** Paused — second passphrase enrolled and verified on 2026-08-12;
boot proof, durable header backup, and convenience-unlock choice remain
**Date:** 2026-08-12
**Last reviewed:** 2026-08-12
**Owners:** `desktop-nixos` (host disk and early-boot configuration), `homelab`
(decision record and gates), and the operator (credential custody)

## Goal

Keep two independently usable LUKS recovery paths for Endeavour and evaluate a
convenient unlock method without weakening pre-boot authentication or putting
unsupported biometric code in the disk-unlock trust path.

This proposal does not authorize passphrase removal, token enrollment, driver
installation, or another LUKS metadata change. Each requires its own explicit
approval after the gates below pass.

## Verified state

- Endeavour root uses LUKS2 on `/dev/nvme0n1p2`, mapped as `cryptroot`.
- Keyslots `0` and `1` are active. Each passphrase passed
  `cryptsetup open --test-passphrase`; slot `0` was not changed.
- No LUKS2 hardware token is enrolled.
- The mode-`0600` secret handoff and temporary header backup were deleted after
  slot `1` verification. No passphrase value entered Git, chat, logs, or command
  arguments.
- Endeavour's
  [disko configuration](https://github.com/ErikBPF/desktop-nixos/blob/main/modules/hosts/endeavour/hardware.nix)
  declares an install-time `passwordFile`. Rebuilding NixOS does not rotate or
  synchronize live LUKS keyslots.

## Decisions

1. Retain both passphrases until the new passphrase succeeds during a normal
   boot and a current header backup exists off-device.
2. Treat the built-in fingerprint reader as post-boot authentication hardware,
   not a LUKS credential.
3. Prefer a dedicated FIDO2 token with `hmac-secret` support if convenient
   pre-boot unlock is still wanted. Keep passphrase fallback.
4. Do not install an untrusted proprietary fingerprint driver in an
   authentication path. Revisit only through upstream libfprint or a trusted,
   reproducible NixOS package.

## Remaining gates

| Gate | Evidence required | State |
|---|---|---|
| G1 — boot proof | Unlock Endeavour once with the slot `1` passphrase during a normal maintenance reboot. | Open |
| G2 — custody | Record primary/recovery roles in the password manager; keep all values outside repositories. | Open |
| G3 — recovery | Store a fresh LUKS header backup in an encrypted, off-device location and record only its non-secret location. | Open |
| G4 — convenience choice | Choose FIDO2 enrollment, keep dual passphrases only, or explicitly defer convenience unlock. | Open |
| G5 — retirement | If one passphrase should be removed, obtain separate destructive approval after G1–G3 and test the surviving credential again. | Blocked on G1–G3 |

Restoring an older LUKS header also restores its older keyslot state. Refresh
the durable backup after every future keyslot change.

## Fingerprint feasibility

- The built-in reader is FocalTech `2808:c652`.
- It is not a FIDO2 device and cannot participate in systemd's early-boot LUKS
  FIDO2 flow.
- `2808:c652` is absent from the
  [upstream libfprint supported-device list](https://fprint.freedesktop.org/supported-devices.html).
- `fprintd` is disabled. The
  [Hyprlock configuration](https://github.com/ErikBPF/desktop-nixos/blob/main/modules/desktop/hyprlock.nix)
  enables fingerprint UI, but no working backend exists.
- Community proprietary drivers have weak provenance and takedown history.
  They are not acceptable for LUKS. If trusted support appears later, first
  test enrollment and verification in isolation, then limit the first PAM
  integration to screen unlock with password fallback.

## Completion criteria

This proposal can close when G1–G4 have recorded outcomes, a current encrypted
off-device header backup exists, and the chosen steady state is one of:

- two retained passphrases;
- two passphrases plus a tested FIDO2 token; or
- one retained passphrase after separately approved keyslot retirement.

Fingerprint support may remain deferred without blocking closure.

## Secret handling

Pass secrets only through a purpose-named `*.secrets.json` handoff in the
owning repository root, mode `0600`. Never paste passphrases into chat, command
arguments, logs, or Git. Delete the handoff immediately after the credential
reaches its sanctioned LUKS keyslot.
