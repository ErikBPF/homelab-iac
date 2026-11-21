# Kepler Wazuh backup credential reader

**Status:** Source preparation only; no policy applied, credential issued, or backup enabled.

## Outcome and boundary

The accepted Wazuh backup plan uses encrypted local Kepler backups and an isolated
restore rehearsal. Its root capture controller needs narrowly scoped Kubernetes
access to coordinate the Wazuh managers. Kepler's existing Harbor credential must
not gain this authority. This change adds a separate Vault policy and AppRole to
the existing `runtime-secret-foundation` root-bootstrap module. That unit remains
excluded from unattended drift; adopted-unit fixtures and apply scope are unchanged.

Identity `svc-desktop-nixos-kepler-wazuh-manager-scale-reader` can only read
`secret/data/fleet/wazuh/manager-scale/kepler`. The runtime document's `token`
field belongs to Kubernetes identity `svc-desktop-nixos-wazuh-manager-scale` in
namespace `wazuh`. GitOps owns its exact named scale/metadata permissions. The
Vault policy grants no wildcard, list, metadata, write or Harbor access and omits
the default policy. Vault login tokens have a 300-second maximum lifetime;
SecretIDs expire after 90 days, following the existing fleet-reader pattern.
No secret value, SecretID resource or Kubernetes token enters Terraform state.

This reader does not authenticate OpenSearch snapshot APIs. Those need a separate
producer identity, runtime credential and reviewed permissions. It also grants no
restore, alert-deletion or production secret-inspection authority.

## Bootstrap and rotation plan

1. After separate operational authorization, the existing root-bootstrap owner
   reviews a plan for `components/openbao/environments/home/runtime-secret-foundation`.
   Accept only the new policy and AppRole; stop on unrelated changes. Bootstrap
   authentication uses the sanctioned ephemeral administrative session, never a
   token in Git, a command argument, a report or a shell trace.
2. Apply that reviewed additive plan only when authorized. Resolve the new role ID
   and issue its SecretID through a private handoff. Desktop owns dedicated
   root-only Sops entries `openbao/wazuh-manager-scale-kepler-role-id` and
   `openbao/wazuh-manager-scale-kepler-secret-id`, plus Vault Agent configuration
   on Kepler. These names are agreed but not provisioned. Existing Harbor entries are untouched.
3. GitOps provisions the separate Kubernetes credential under its accepted RBAC.
   An authorized operator writes only the `token` field to the exact Vault path
   using the sanctioned private handoff. No standing publisher is added here.
   No existing short-lived Kubernetes renewal controller has been established;
   a static service-account-token fallback must remain disabled until its
   rotation owner and procedure are explicitly recorded.
4. Desktop's dedicated Vault Agent authenticates with this AppRole and renders a
   mode-0600 root-owned `/run/wazuh-manager-scale/token` file. The controller reads that file;
   neither its argv nor logs carry the token. Verify allowed reads and denied
   neighboring paths without printing values, then validate the capture fixture.
5. Rotate the AppRole SecretID before 90 days: provision a replacement privately,
   verify consumer authentication, revoke the old SecretID by accessor. Vault
   tokens expire after five minutes; reauthentication requires the valid SecretID.
   With the default policy omitted, do not assume `renew-self` is available:
   verify the actual Vault Agent expiration/reauthentication cycle and denied
   neighboring paths before enabling captures. A failed cycle blocks activation;
   granting extra capabilities requires a separately reviewed policy change.
   Kubernetes credential rotation is independent: publish replacement, verify
   permitted API access, then revoke the old credential. A failed rotation keeps
   schedules disabled; it never authorizes widening permissions.

## Evidence, limits and rollback

The offline contract first failed with `dedicated Kepler Wazuh reader missing`.
After implementation, all 16 targeted ownership, drift and new reader tests
passed. Targeted TFLint under an empty inherited environment, OpenTofu formatting
and diff checks also passed. The contracts verify exact path/capability, separate identity, TTLs, no default
policy, no secret resource, and retained exclusions. These are source contracts,
not a live Vault authorization or Kubernetes rotation proof. An independent
reviewer reproduced all 16 contracts under an empty inherited environment and
found no material issue, including after the reauthentication clarification. Session receipts are
`/tmp/wazuh-vault-red.log` and `/tmp/wazuh-vault-green.log`.

Rollback disables the dependent capture schedule before retiring this dedicated
AppRole/policy and revoking its credentials. Existing Harbor access and unrelated
Vault foundation resources must remain intact. Source publication is useful now;
bootstrap, delivery, rotation and live recovery evidence remain separate work.
