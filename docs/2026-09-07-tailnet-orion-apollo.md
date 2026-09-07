# Orion/Apollo Tailnet transition

**Status:** Reviewed source; authenticated policy validation and wired-host plan
precede apply. User authorized updating the Tailnet after Gemini retirement.

The live policy matches the existing local Apollo API/cache additions. This
change publishes those additions, removes Gemini's alias/grants/tests, permits
Galaxy SSH only to Orion/Apollo/Endeavour, and permits SSH between Orion and
Apollo. Fleet-wide SSH remains restricted to existing admin devices. Apollo's
Kubernetes API stays admin-only; existing NAS, DNS, observability, SWAG and
backup boundaries remain unchanged. No Syncthing topology is activated here.

Run from an isolated checkout of this revision on wired Orion; its route to
192.168.10.1 must use `enp4s0` with source 192.168.10.220, not Wi-Fi/Tailscale.
Load only the required Tailscale OAuth, MinIO backend and state-encryption keys
from the existing Sops bootstrap source into process environment. When handed
from the operator workstation, use encrypted SSH stdin without printing or
writing plaintext credentials. Preserve all dirty canonical checkouts.

```sh
cd tailscale/acl
export TG_TF_PATH="$(command -v tofu)"
export AWS_ACCESS_KEY_ID="$MINIO_TFSTATE_ROOT_USER"
export AWS_SECRET_ACCESS_KEY="$MINIO_TFSTATE_ROOT_PASSWORD"
terragrunt init -input=false -lockfile=readonly
terragrunt plan -input=false -out=/tmp/tailnet-orion-apollo-20260907.tfplan
# Review only the ACL change; preserve NanoKVM key-expiry state.
terragrunt apply -input=false /tmp/tailnet-orion-apollo-20260907.tfplan
terragrunt plan -input=false -detailed-exitcode
```

The expected change is one in-place `tailscale_acl.this` update, no creates or
destroys. Do not apply unrelated changes. Provider/API validation must run every
embedded allow/deny test. Keep the encrypted saved plan and filtered resource
summary private; do not print plan variable values. Re-read the API policy after
apply and compare it structurally with the committed HuJSON.

Gemini's device registration is not Terraform-managed. After the policy apply,
remove only device ID `4165363960594091` (node `nxVaan3WXZ11CNTRL`), hostname
`gemini`, IPv4 `100.91.131.59`, tag `tag:server`. Re-read the device immediately
before deletion; require that identity tuple, no newer `lastSeen` than the
retired inventory (`2026-09-07T05:05:43Z`), and absent Gemini config/root on Orion.
Use Tailscale's documented `DELETE /api/v2/device/{deviceID}`, through the
existing OAuth identity; do not rotate shared keys or revoke other devices.
If any guard changes, stop this deletion and investigate. Verify the exact
registration is absent afterwards and all other device IDs are retained.

References: [device removal](https://tailscale.com/docs/features/access-control/device-management/how-to/remove)
and [OAuth API scopes](https://tailscale.com/docs/reference/trust-credentials).
Verify Orion/Apollo SSH transport, Apollo's Orion Nix-cache access, existing
admin SSH and critical services after apply. Mobile policy tests prove network
permissions; actual phone authentication remains a separate client check.
