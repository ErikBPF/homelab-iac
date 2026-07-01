# oracle — Always-Free Ampere A1 offsite host (`voyager`)

Creates the whole stack for the fleet's offsite backup receiver on Oracle
Cloud, from a clean slate: VCN + subnet + internet gateway + route table +
security list + the A1 instance. The instance boots Ubuntu (aarch64) as the
install entrypoint; `desktop-nixos` then converts it to NixOS via
`just deploy-voyager` (nixos-anywhere).

## Layout
- `root.hcl` — generates the `oci` provider (creds from `.env.sops`) + pbkdf2
  state encryption, MinIO S3 backend (shared `backend.hcl`).
- `modules/instance/` — network + instance.
- `compute/` — the `voyager` unit.
- `bin/upgrade-retry.sh` — loops the shape upgrade until capacity frees.

## Secrets (`.env.sops`)
`OCI_tenancy_ocid`, `OCI_user_ocid`, `OCI_fingerprint`, `OCI_private_key_b64`
(base64 of the API signing-key PEM), `OCI_region`, `OCI_compartment_ocid`.
Optional: `OCI_availability_domain`, `OCI_SSH_PUBKEY_FILE`, and the shape knobs
`OCI_OCPUS` / `OCI_MEMORY_GBS` (see below).

## Apply
```
cd oracle/compute
terragrunt apply        # via direnv (devenv provides tofu/terragrunt)
```
Output `public_ip` → set as `ip_voyager` in `desktop-nixos/justfile` →
`just deploy-voyager`.

## A1 capacity
`sa-saopaulo-1` has a single AD and free A1 capacity is intermittent
("500-InternalError, Out of host capacity"). The network always lands; only the
instance waits. Retry `apply` until it succeeds — smaller shapes land far more
easily, which is why we start at **1 OCPU / 6 GB**.

## Shape & the upgrade plan
The shape is env-driven (`compute/terragrunt.hcl`), defaulting to the
capacity-friendly **1 OCPU / 6 GB** to validate the flow. The free A1 pool is
**4 OCPU / 24 GB total**; the target is **2 OCPU / 12 GB** once capacity allows.

Upgrade (in-place resize, reboots the instance — only the delta needs capacity):
```
cd oracle/compute
OCI_OCPUS=2 OCI_MEMORY_GBS=12 terragrunt apply
```
Or let it retry on a schedule until capacity frees:
```
OCI_OCPUS=2 OCI_MEMORY_GBS=12 bash ../bin/upgrade-retry.sh
```
Run this only **after** `voyager` exists at 1 OCPU — it resizes an existing
instance, it does not create one.
