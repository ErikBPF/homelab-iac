# Orion/Apollo Tailnet transition

**Status:** Applied and verified on wired Orion on 2026-09-07; Gemini registration removed.
User authorized updating the Tailnet after Gemini retirement.

The pre-apply live policy matched the pending local Apollo API/cache additions.
This change publishes those additions, removes Gemini's alias/grants/tests, permits
Galaxy SSH only to Orion/Apollo/Endeavour, and permits SSH between Orion and
Apollo. Fleet-wide SSH remains restricted to existing admin devices. Apollo's
Kubernetes API stays admin-only; existing NAS, DNS, observability, SWAG and
backup boundaries remain unchanged. No Syncthing topology is activated here.

Run from an isolated checkout outside synchronized directories on wired Orion.
The applied checkout was `/var/tmp/tailnet-iac-20260907` at merged revision
`6e46ab50082440ab5ad761697b72bc3fd5587e55` (PR #103). Syncthing changed the
runbook in the earlier Documents worktree, so a fresh plan was generated in
`/var/tmp` before applying; the original dirty worktree was preserved. Its route to
192.168.10.1 must use `enp4s0` with source 192.168.10.220, not Wi-Fi/Tailscale.
Load only the required Tailscale OAuth, MinIO backend and state-encryption keys
from the existing Sops bootstrap source into process environment. When handed
from the operator workstation, use encrypted SSH stdin without printing or
writing plaintext credentials. Preserve all dirty canonical checkouts.

Orion's system `tofu` is a tenv wrapper without a selected version. Copy the
repository devenv's pinned tool closures, then use their real binaries:

```sh
NIX_SSHOPTS='-p 2222' nix copy --to ssh://erik@orion /nix/store/yp4yp9jvs8lhymvxpm2z0nk91fb2sy61-opentofu-1.12.1 /nix/store/ppq9ngp679b4v1fr99qymivm83k5bhpk-terragrunt-1.0.4
```

On wired Orion with the bootstrap environment loaded:

```sh
export PATH=/nix/store/ppq9ngp679b4v1fr99qymivm83k5bhpk-terragrunt-1.0.4/bin:$PATH
cd tailscale/acl
export TG_TF_PATH=/nix/store/yp4yp9jvs8lhymvxpm2z0nk91fb2sy61-opentofu-1.12.1/bin/tofu
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

## Reviewed plan evidence

OpenTofu 1.12.1 and Terragrunt 1.0.4 from the repository devenv produced a saved
plan on wired Orion: 0 add, 1 change, 0 destroy. The only change is
`tailscale_acl.this`; `tailscale_device_key.nanokvm` is unchanged. Filtered plan
JSON matches the captured live policy before and the committed candidate after.
All 10 Tailnet Bats contracts and authenticated server-side policy validation pass.
No provider constraints, lockfiles, backend settings or credential values changed.

## Applied result

The saved plan applied successfully: only `tailscale_acl.this` changed. The API
policy equals the merged HuJSON structurally; all 38 embedded allow/deny cases
passed authenticated validation. The subsequent OpenTofu plan returned exit 0
with no changes. NanoKVM key-expiry configuration remained unchanged.

Gemini's exact device identity and offline timestamp matched the deletion guards;
its container config/root were absent and service inactive. The API deletion
removed device `4165363960594091`; every other prior device ID remained present.

Admin SSH to both hosts passed. Tailnet TCP connections in both Orion/Apollo
SSH directions returned OpenSSH banners, and Apollo fetched Orion's
`/nix-cache-info` successfully. These transport probes do not assert user-key
authentication between hosts. Orion inference returned `{"status":"ok"}`;
neither host had failed system units. Actual Galaxy client login remains untested.
