# Endeavour LUKS authentication and convenience unlock

**Status:** In progress — two passphrases remain, TPM2 slot `2` is enrolled and
validated, both header backups are verified off-device, and a normal TPM boot
reached SDDM; passphrase-fallback proof and custody remain
**Date:** 2026-08-12
**Last reviewed:** 2026-08-16
**Owners:** `desktop-nixos` (host disk and early-boot configuration), `homelab`
(decision record and gates), and the operator (credential custody)

## Goal

Keep two independently usable LUKS recovery paths for Endeavour while adding
TPM2 convenience unlock. Treat the current unsigned GRUB boot chain as an
explicit convenience compromise, not equivalent protection against a stolen
machine with a modified boot chain.

The operator explicitly approved TPM2 enrollment on 2026-08-16. This does not
authorize passphrase removal, fingerprint-driver installation, Secure Boot key
enrollment, or another destructive LUKS metadata change.

## Verified state

- Endeavour root uses LUKS2 on `/dev/nvme0n1p2`, mapped as `cryptroot`.
- Keyslots `0` and `1` are active. Each passphrase passed
  `cryptsetup open --test-passphrase`; slot `0` was not changed.
- TPM2 token `0` uses keyslot `2` and a PCR 7 policy. A direct
  `systemd-cryptenroll --unlock-tpm2-device=auto` check succeeded after
  enrollment. Password keyslots `0` and `1` remain active.
- Secure Boot is disabled and Endeavour boots through GRUB rather than a signed
  unified kernel image. TPM2 unlock is therefore convenience-first until a
  signed measured-boot chain is migrated separately.
- A mode-`0600`, root-owned pre-enrollment header backup exists at
  `/home/erik/.local/state/luks-header-backups/nvme0n1p2-05770081-pre-tpm-2026-08-16.img`
  beside its post-enrollment replacement. Both paths were listed directly from
  encrypted off-device restic snapshot `0cc76d23`.
- Generation
  `/nix/store/kcrfnwp5rf88s13gwq4aisi1jshwljl0-nixos-system-endeavour-26.11.20260816.e5bdc4a`
  is active. Its initrd crypttab contains `tpm2-device=auto`, and its active
  SDDM configuration has no autologin section.
- The 2026-08-16 reboot opened `cryptroot` without operator input in about
  0.48 seconds, reached the SDDM greeter, authenticated `erik`, and reported
  that `pam_gnome_keyring` unlocked the login keyring.
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
3. Use TPM2 PCR 7 unlock on Endeavour for convenience now. Keep both
   passphrases. Do not present this as evil-maid or modified-boot protection
   while Secure Boot remains disabled.
4. Do not install an untrusted proprietary fingerprint driver in an
   authentication path. Revisit only through upstream libfprint or a trusted,
   reproducible NixOS package.
5. Prove the signed-boot design on Pathfinder before considering a Secure Boot
   migration on Endeavour.

## Remaining gates

| Gate | Evidence required | State |
|---|---|---|
| G1 — boot proof | Reboot Endeavour once, prove unattended TPM2 root unlock reaches SDDM, then prove a retained passphrase still works after forcing TPM fallback. | Partial — TPM boot to SDDM proved 2026-08-16; forced passphrase fallback open |
| G2 — custody | Record primary/recovery roles in the password manager; keep all values outside repositories. | Open |
| G3 — recovery | Store pre- and post-enrollment LUKS headers in the encrypted off-device Endeavour restic repository. | Complete — both paths verified in snapshot `0cc76d23` on 2026-08-16 |
| G4 — convenience choice | Explicitly select TPM2 PCR 7 convenience unlock while retaining both passphrases and accepting the unsigned-chain limitation. | Complete — 2026-08-16 |
| G5 — deployment | Deploy the initrd `tpm2-device=auto` option and SDDM login requirement without unintentionally deploying unrelated worktree changes. | Complete — closure delta was initrd-only; generation activated 2026-08-16 |
| G6 — retirement | If one passphrase should be removed, obtain separate destructive approval after G1–G3 and test the surviving credential again. | Blocked on G1–G3 |

Restoring an older LUKS header also restores its older keyslot state. Refresh
the durable backup after every future keyslot change.

## Safe signed-boot canary plan

Use Pathfinder only after it is online and each gate succeeds. Its declarative
configuration already uses LUKS and systemd-boot; the 2026-08-16 read-only SSH
probe timed out, so live TPM2 and firmware eligibility are still unknown.

1. **Eligibility:** at the physical console, verify UEFI boot, TPM2 support,
   firmware Secure Boot controls, ESP free space, LUKS2 root, two working
   passphrases, and a tested recovery boot path. Create an encrypted off-device
   header backup before changing firmware or LUKS metadata.
2. **Signed artifacts:** pin a stable
   [Lanzaboote](https://github.com/nix-community/lanzaboote) release in
   `desktop-nixos`, import it for Pathfinder only, replace that host's direct
   systemd-boot enablement, and keep `/var/lib/sbctl` root-only. Dry-build and
   deploy while firmware remains in Secure Boot Setup Mode.
3. **Key custody:** generate keys with `sbctl` on Pathfinder. Store an encrypted
   off-device copy of `/var/lib/sbctl`; never commit private PK, KEK, or db keys
   or expose them through the Nix store.
4. **Boot enforcement:** verify all expected EFI executables and unified kernel
   images with `sbctl verify`. Enroll keys while physically present, preserve
   Microsoft/firmware keys required by OptionROMs, enable Secure Boot, then
   confirm `bootctl status` reports enabled user mode and the recovery entry
   still boots.
5. **TPM canary:** only after signed boot is proven, enroll Pathfinder's LUKS
   token against PCR 7, retaining both passphrases. Refresh the off-device
   header backup, reboot normally, then deliberately force TPM policy mismatch
   and prove passphrase recovery.
6. **Observation:** keep Pathfinder as the only canary through at least one
   normal kernel/initrd update and rollback. Promote the design to Endeavour
   only after signed-update, rollback, TPM unlock, and passphrase fallback
   evidence all pass.

Stop at any failed gate. Firmware key enrollment, LUKS token changes, and
reboots each require their own maintenance action; this plan authorizes none of
them on Pathfinder.

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
- two passphrases plus a tested TPM2 token; or
- one retained passphrase after separately approved keyslot retirement.

Fingerprint support may remain deferred without blocking closure.

## Secret handling

Pass secrets only through a purpose-named `*.secrets.json` handoff in the
owning repository root, mode `0600`. Never paste passphrases into chat, command
arguments, logs, or Git. Delete the handoff immediately after the credential
reaches its sanctioned LUKS keyslot.
