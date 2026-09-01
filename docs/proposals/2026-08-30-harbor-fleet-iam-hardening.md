# Authentik-backed Harbor and fleet IAM capabilities

**Status:** In progress — S0-S1, S2R, S4 control-plane reconciliation, and the
Discovery/Endeavour reader canaries are complete; Kepler activation, S2
negative/access acceptance, and S3 privileged access remain gated
**Date:** 2026-08-30
**Last reviewed:** 2026-08-31
**Owners:** `homelab` (decision and behavior contract), `homelab-gitops`
(Authentik runtime), `homelab-iac` (Authentik/Harbor/OpenBao resources and
Tailscale policy), `desktop-nixos` (fleet roster, cluster substrate, OpenBao,
and host credential projection), and `servarr` (Harbor runtime and SWAG)

## Decision

Keep Harbor and introduce self-hosted Authentik as the authoritative human
OIDC provider. Required behavior must work without an Authentik Enterprise
license, hosted identity service, metered tier, or external identity provider.
Cloudflare Access remains an independent edge control plane; it is not required
for core LAN or tailnet login.

Humans authenticate through Authentik. Every approved human is a Harbor reader
through the exact `harbor-readers` group; administration requires the separate
flat `harbor-admins` group. Machines do not use human OIDC: every host in the
pinned `desktop-nixos` fleet gets a distinct pull-only Harbor robot. Writers
remain named producer robots with project-scoped push access.

Do not create `homelab-iam`. The existing ownership boundaries are sufficient:

- `homelab-gitops` owns the Authentik server, worker, ingress, persistence, and
  database workload.
- `homelab-iac` owns Authentik directory/application resources, Harbor policy,
  OpenBao records, and required network policy through app-scoped components.
- `desktop-nixos` owns the canonical fleet and projects machine credentials only
  to supported consumers.
- OpenBao owns runtime values; Sops retains bootstrap and break-glass material.
- `servarr` owns Harbor and SWAG lifecycle, but not the identity provider.

Reuse the useful `dataplatform-adb-iam` layout properties already identified:
an app-scoped IaC boundary, explicit provider inputs, isolated encrypted state,
and no runtime dependency on another working tree. Do not copy its repository
shape merely to create another repository.

This phase establishes implementation capability. Authentik and Harbor backup
objectives, restore drills, and HA topology remain a later decision.

Initial placement remains the Kepler Kubernetes cluster behind Discovery's
AdGuard-to-SWAG path. Discovery does not host Authentik. This deliberately
accepts Kepler as one physical compute/database failure domain and Discovery as
the private DNS/ingress failure domain; later HA work must harden DNS, ingress,
and PostgreSQL before extra Authentik replicas can provide real failover.

## Corrected current state

Source inspection on 2026-08-30 establishes:

- There is no configured human OIDC provider in the three workload/control
  repositories. Argo CD disables Dex and uses its local administrator.
- Cloudflare Access manages self-hosted applications with email and service-token
  policies. It is an edge access service, not the desired self-hosted directory.
- Platform OpenBao is the NixOS service on Discovery: Raft storage, Sops-held
  bootstrap, AppRole machine authentication, restricted loopback/tailnet/SWAG
  listeners, ESO lanes, snapshots, and restore drills. It declares no human
  OIDC auth method or identity directory.
- The HashiCorp Vault dev container still present in Servarr `infra.compose.yml`
  is a legacy runtime. It must not receive Authentik integration or new secrets.
- Authentik was dropped from the old Discovery Compose stack, but no source
  shows a product failure. Reintroducing it as a Kubernetes workload has clean
  ownership and avoids restoring the former mixed stack.
- Harbor currently uses database authentication and SWAG HTTPS. Machine pulls
  already rely on Harbor credentials, and the current canonical fleet contains
  ten hosts.
- The cluster already provides Argo CD, Traefik, External Secrets Operator,
  OpenBao-backed secret lanes, and persistent storage. These are sufficient
  seams for an Authentik workload; they do not prove sizing or rollout safety.

## Web-grounded capability boundary

- Authentik core is MIT-licensed; separately licensed enterprise code is kept
  under its own directory. Required OIDC, users, groups, policies, API, MFA,
  WebAuthn/passkeys, and application providers are core capabilities.
  [Authentik license](https://github.com/goauthentik/authentik/blob/main/LICENSE)
- Authentik has an official Kubernetes Helm chart. Its bundled PostgreSQL is
  explicitly for demonstration/testing; a production deployment uses a
  separately managed PostgreSQL service.
  [Kubernetes installation](https://docs.goauthentik.io/install-config/install/kubernetes/)
- The official Terraform provider manages Authentik resources through its API.
  Use provider resources directly; no third-party Terraform module is required.
  [Authentik provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- The Harbor provider manages auth configuration, projects, groups, and robots.
  Use it directly inside the Harbor component; a generic community module would
  add no ownership or safety boundary.
  [Harbor provider](https://registry.terraform.io/providers/goharbor/harbor/latest/docs)
- Authentik documents direct Harbor OIDC integration and strict redirect URIs.
  [Harbor integration](https://integrations.goauthentik.io/services/harbor/)
- Authentik supports WebAuthn/FIDO2/passkeys, including platform and roaming
  authenticators. This is the privileged-user MFA baseline; email recovery is
  optional, not a required external dependency.
  [WebAuthn stage](https://docs.goauthentik.io/add-secure-apps/flows-stages/stages/authenticator_webauthn/)
- Authentik can be an upstream IdP for Cloudflare Access, but the official flow
  requires a publicly reachable Authentik endpoint with trusted TLS. That is
  rejected for the first private deployment.
  [Cloudflare Access integration](https://docs.goauthentik.io/integrations/services/cloudflare-access/)

## Required license-independent capability

| Required capability | Authentik core seam | Paid dependency |
|---|---|---|
| Local users and flat authorization groups | Directory, groups, bindings | None |
| OIDC authorization-code clients | OAuth2/OIDC providers | None |
| MFA and passkeys | TOTP and WebAuthn stages | None |
| Exact group claims | Scope mappings and application bindings | None |
| Declarative resources | Official Terraform provider and API | None |
| Kubernetes runtime | Official Helm chart | None |
| Harbor, Argo CD, Grafana, and OpenBao clients | Standards-based OIDC | None |

Any later requirement that needs a licensed Authentik feature reopens product
selection; it is not silently added to the implementation plan.

## Decision map

### Destination

An approved operator can authenticate to Harbor through private Authentik with
strong MFA and exact group authorization. Every managed fleet host can pull
from declared Harbor projects with its own revocable identity. Neither path
depends on Cloudflare availability, an enterprise license, or a shared secret.

### Actors and outcomes

| Actor | Outcome |
|---|---|
| Approved human | Authentik login; reader by default; no implicit administration |
| IAM administrator | Separate Authentik administration with phishing-resistant MFA and independent recovery |
| Harbor administrator | Exact `harbor-admins` membership plus retained local break-glass path |
| Fleet host | Unique pull-only Harbor robot derived from the pinned fleet roster |
| Producer | Unique project-scoped push/pull robot; never inherits fleet access |
| Workload | Distinct OIDC client or machine secret with no cross-application reuse |

### Settled decisions

1. Authentik is the authoritative human directory and OIDC issuer. OpenBao is
   runtime secret storage, not an identity provider.
2. Harbor consumes Authentik directly. Cloudflare Access may consume Authentik
   only in a later, separately accepted public-endpoint design.
3. Authentik is private: fleet DNS routes its trusted HTTPS name through the
   existing Discovery SWAG and Tailscale path to the Kubernetes ingress. No
   public tunnel or dedicated backend port is added. Kepler's existing shared
   LAN ingress remains reachable with an explicit Host header; its L4 proxy
   hides source IP, so it cannot truthfully enforce a SWAG-only allowlist.
4. All approved humans are members of the flat `harbor-readers` group. The
   flat `harbor-admins` group is separate, exact-match, has no parent or child
   groups, and is initially empty until an administration canary passes. Nested
   group inheritance is not used for privileged authorization.
5. Human identities never replace Harbor robots. Every pinned fleet host
   receive distinct pull-only robots for explicitly readable projects,
   initially `library` and `dockerhub`.
6. Fleet membership never grants write. The first source-proven writer remains
   a `library-mirror` producer robot; future writers require an owner and named
   projects.
7. Human clients use authorization code flow, confidential clients, exact
   redirects, trusted TLS, signed tokens, minimal scopes, filtered group claims,
   and short sessions. Wildcard redirects and implicit/hybrid grants are
   rejected.
8. Routine users require MFA. The flat `authentik-admins` and `harbor-admins`
   groups require WebAuthn. Recovery must work without email or Cloudflare and
   must not weaken normal authentication.
9. Machine paths stay independent: Harbor robots and OpenBao AppRole continue
   working when Authentik is unavailable. Local Harbor and Authentik
   break-glass paths remain independently recoverable.
10. Authentik bootstrap and break-glass material stays in Sops. Separable
    runtime database and machine values stay in OpenBao. Use ephemeral values
    and write-only provider attributes where supported. The Authentik provider
    currently lacks a write-only OIDC client-secret field; that client value is
    confined to isolated encrypted state and never emitted through plaintext
    plans, outputs, logs, tests, or evidence.
11. Harbor is the first relying party. Argo CD, Grafana, OpenBao human UI/CLI,
    and Dockhand are later direct-OIDC canaries, each with its own client and
    bindings. Proxy outposts are not introduced for OIDC-capable applications.
12. No new IAM repository or generic Terraform module is created. Reconsider
    only after repeated ownership or lifecycle friction is observed.
13. Standing machine identities use
    `<identity-type>-<controller>-<target>-<capability>`, retaining any
    product-required prefix. Separate target trust boundaries never share a
    credential. Current names are
    `svc-homelab-iac-authentik-config-manager` and
    `robot$homelab-iac-harbor-project-iam-manager`; fixed upstream break-glass
    users remain `akadmin` and `admin`.
14. Harbor day-two membership uses member CRUD only on `library` and
    `dockerhub`; future projects are denied until explicitly added. Its runtime
    credential is retrieved through the dedicated exact-read AppRole
    `svc-homelab-iac-openbao-harbor-project-iam-reader`, never the broad IaC
    writer identity. Publication uses the separate exact-path identity
    `svc-homelab-iac-openbao-harbor-project-iam-publisher`. Both SecretIDs
    expire after 90 days; recapture revokes prior accessors before replacement.
15. Harbor's list-users response is not authoritative for OIDC provenance.
    Migration evidence resolves each non-administrator user through the
    per-user endpoint and emits only a boolean classification.
16. The Authentik config-manager token expires after 90 days and is rotated
    directly into Sops. The Harbor project-IAM robot expires at
    `2027-08-31T20:47:38Z`; overlap rotation must land at least 30 days earlier.

### Dependencies and factual preflights

- Reconcile live Harbor `2.14.4` with source `2.15.2` before changing auth.
- Inventory non-admin Harbor local users; Harbor auth-mode changes have migration
  constraints.
- Render and verify the exact Harbor callback and Authentik issuer through the
  same trusted hostname from browsers and the Harbor container network.
- Prove the SWAG-to-Kubernetes route and Tailscale ACL without opening Authentik
  publicly or allowing a broad bridge/subnet rule.
- Select the smallest existing GitOps PostgreSQL pattern that meets Authentik's
  production requirement; do not use the chart's demonstration database.
- Bootstrap the Terraform API token without making Authentik availability a
  prerequisite for OpenBao AppRole or Sops recovery.
- Inventory every fleet host's real Harbor consumer before projecting a robot
  credential; unused credentials remain only in OpenBao.

### Risks and review gates

| Risk | Required gate |
|---|---|
| OIDC or group misconfiguration grants admin | Exact flat-group claim canary; no auto-admin initially |
| Authentik outage locks out operations | Robot/AppRole independence plus local break-glass proof |
| Kubernetes identity service becomes circular dependency | Sops bootstrap, OpenBao AppRole, and local Argo admin remain independent |
| Authentik becomes accidentally public | DNS, SWAG, listener, Tailscale, and negative public reachability tests |
| Terraform token or client secret leaks | Write-only fields where supported, encrypted-state inspection, no secret outputs, and secret-negative evidence |
| Passkey loss locks out sole operator | Two independent privileged authenticators plus tested offline recovery |
| Product later gates a required feature | License audit blocks adoption of that feature and reopens selection |

### Out of scope

- Authentik or Harbor HA topology, backup policy, restore objectives, and DR.
- Public Authentik exposure or Authentik as Cloudflare Access upstream.
- LDAP, SCIM, social login, device inventory, or enterprise-only features.
- Migrating every SWAG application or adding forward-auth snippets globally.
- Replacing Harbor, OpenBao, Tailscale, SWAG, or Argo CD.
- Retiring the legacy Servarr Vault dev container; it receives no new usage.

### Frontier

S0-S1 are accepted. S2 configuration is live, but its denied push/delete,
unbound-user, Internet/Cloudflare-independence, and license/external-IdP checks
remain acceptance gates. S3 must then prove WebAuthn and both independent
break-glass paths before enabling any OIDC administrator group. Fleet robots
and additional relying parties remain separate vertical slices.

## Behavior agreement

[`docs/behaviors/harbor-iam/hardening.feature`](../behaviors/harbor-iam/hardening.feature)
is the agreed, currently unautomated contract. It replaces Cloudflare Access as
the Harbor OIDC issuer while preserving the accepted fleet-reader,
explicit-writer, private-ingress, and break-glass behavior.

## `/ip` implementation plan

### Fixed point and delivery rule

The feature above is the fixed behavior. This plan does not select HA, backup,
LDAP, SCIM, public Authentik, or a new IAM repository. If implementation shows
that a paid feature or public issuer is required, stop and return to `/pl`.

Land leaf-first, then consumers, then deployment. Never make one repository
read another working tree. Publish or vendor each reviewed revision through the
existing repository mechanisms before updating its consumer.

### Test seams

Use the fewest seams that cover distinct failures:

| Seam | Catches | Misses / cost |
|---|---|---|
| Source and render contracts in each owner repo | Missing resources, wildcard redirects, broad permissions, secret outputs, wrong ownership, invalid Helm/Kustomize/Nix/HCL | Cannot prove provider or runtime behavior; cheap and runs in CI |
| Encrypted OpenTofu plan plus JSON assertions | Provider schema compatibility, destructive changes, exact resource counts and permissions | Needs live read credentials; plans must stay in a mode-0700 temporary directory |
| Live canary scripts using Authentik, Harbor, OpenBao, Docker, SWAG, and Tailscale | Real claims, MFA, authorization, pull/push denial, revocation, routing, TLS, and outage independence | Mutates canary identities and needs operator presence; run only at rollout gates |

Do not add Cucumber merely to parse prose. Bind the scenarios through a thin
`homelab/tests/harbor-iam-acceptance.sh` orchestrator that delegates to
owner-repository acceptance commands and records only pass/fail metadata. Keep
`@unautomated` until every scenario has a runnable binding that has been seen
failing for the expected missing behavior.

Planned owner-side checks:

- `homelab-gitops/tests/authentik-contract.sh`, included by
  `scripts/validate.sh` and `just test`.
- `homelab-iac/tests/authentik-harbor-iam-contract.bats` plus the existing
  OpenBao and Tailscale contracts.
- `desktop-nixos/tests/authentik-bootstrap-contract.sh` and
  `tests/harbor-fleet-readers-contract.sh`, included by `just check`.
- `servarr/machines/discovery/tests/test_authentik_proxy_contract.py` and
  `test_harbor_iam_contract.py`.
- Owner-specific live commands named `iam-acceptance`; the root command only
  invokes them in dependency order.

### Scenario-to-slice map

| Slice | Feature scenarios |
|---|---|
| S1 Private Authentik foundation | Serve identity and registry only through trusted private ingress |
| S2 Harbor human OIDC canary | Operate without licensed service; approved human reader; reject unapproved identity; harden OIDC exchange; distinguish OIDC/local users; reconcile membership without bootstrap administration |
| S3 Privileged access and recovery | Require WebAuthn; exact flat admin group; independent break-glass |
| S4 Fleet reader reconciliation | Machine independence; register fleet; project real consumers; distinct credentials; revoke removed host |
| S5 Writer cutover | Admit writer; publish immutable release |
| S6 Private project and offsite acceptance | Offsite fleet reachability; remove anonymous pulls |
| S7 Client and credential lifecycle | Add another relying party; rotate generated credential |

### S0 — Read-only preflight and compatibility gate

**Observable result:** a sanitized evidence record proves the exact live/source
versions, user migration state, fleet parity, routes, and capacity. No resource
changes.

**Checks:**

1. Compare `desktop-nixos/fleet.json` and `homelab-iac/fleet.json`; require the
   same host keys before planning robots.
2. Read Harbor `/api/v2.0/systeminfo`, auth configuration, projects, users, and
   robot metadata without printing credential fields. Stop if a non-admin local
   user blocks the documented database-to-OIDC transition.
3. Reconcile live Harbor `2.14.4` with the source pin `2.15.2`. Pin a Harbor
   provider release tested against the accepted live version before import.
4. Run `just capacity` in `homelab-gitops`; record allocatable CPU, memory, and
   local storage. Stop if Authentik server, worker, and PostgreSQL requests do
   not fit with failure headroom.
5. Resolve the proposed Authentik hostname from LAN, tailnet, and public DNS.
   Public resolution/reachability is a failure; LAN/tailnet must resolve to
   Discovery SWAG.
6. From Discovery and the Harbor container network, prove the future issuer and
   JWKS hostname route can reach the Kubernetes ingress with trusted TLS.
7. Verify the existing wildcard Tailscale rule permits every pinned tailnet host
   to `swag:443` while direct Discovery/Kepler backend ports remain denied.

**Commands:** root `just test && just docs-check`; GitOps `just test`; IaC
`bats tests/*.bats && tofu fmt -check -recursive && terragrunt hcl validate`;
desktop `just fleet-check`; Servarr focused `pytest` tests. Live API wrappers
must redact JSON before writing evidence.

**Gate:** no implementation starts until all checks pass. No rollback is needed
because S0 is read-only.

### S1 — Private Authentik foundation

**Observable result:** `https://authentik.homelab.pastelariadev.com` is healthy
from LAN and approved tailnet hosts through SWAG, has no public DNS/tunnel, and
adds no dedicated backend listener.

**RED:** add the GitOps, desktop bootstrap, and Servarr proxy contracts first.
They must fail because the Authentik chart/application, runtime secrets,
dedicated database, SWAG vhost, and private-path restrictions are absent.

**Minimum GREEN surface:**

- `homelab-iac/components/openbao/environments/home/authentik-runtime/` writes
  Authentik secret-key and PostgreSQL values with the existing write-only
  `kv-secret` pattern under `secret/platform/authentik`.
- Sops stores the recoverable break-glass material and temporary bootstrap API
  token. `desktop-nixos` derives the password hash without placing the password
  in the Nix store and reconciles only a first-start Kubernetes Secret. A
  purpose-named `*.secrets.json` handoff is consumed, never printed, then
  deleted. After initialization, create a least-privilege IaC service
  account/token in the control-plane Sops store, remove the bootstrap Secret and
  environment references from the cluster, revoke the bootstrap API token, and
  remove that revoked token from Sops.
- `homelab-gitops/platform/authentik/` wraps the pinned official chart with
  telemetry/error reporting disabled and bundled PostgreSQL disabled. A
  separately managed, digest-pinned PostgreSQL StatefulSet reuses the existing
  Immich-style `local-path` persistence pattern for this non-HA phase.
- Add ESO, resource requests/limits, probes, NetworkPolicies, monitoring, the
  `authentik` namespace/project destination, Argo Application, and root
  Kustomization entry. No NodePort or LoadBalancer.
- Add the Servarr SWAG vhost targeting the Kepler ingress with the Authentik
  Host header. Do not add a source-IP middleware behind Kepler's source-hiding
  L4 proxy; private DNS, the existing host/tailnet firewall, and Authentik
  authentication are the enforceable boundaries.

**Verification:** GitOps `just test` and `just template authentik`; desktop
`just dry target=discovery`; Servarr focused `pytest`; then sync root and the
new Authentik app at one reviewed commit. Prove health, TLS, issuer discovery,
SWAG access, public denial, tailnet backend denial, pod restart, and PostgreSQL
persistence without exposing values. Confirm the bootstrap Secret and token are
absent from the running namespace after initialization.

**Rollout:** OpenBao path → desktop bootstrap projection → Servarr SWAG source
→ GitOps source → reviewed Argo sync. **Rollback:** sync the prior GitOps
revision and prior SWAG configuration; retain the PVC, OpenBao path, and Sops
bootstrap material for retry. Do not delete state during rollback.

**Live evidence (2026-08-30):** Authentik `2026.5.6` server, worker, and the
digest-pinned PostgreSQL StatefulSet are Ready; ESO reports `SecretSynced`; the
root and Authentik Argo applications are `Synced/Healthy` at GitOps revision
`c9d0c59`. SWAG returns `200` for the health endpoint and `302` at the root;
Discovery and Orion both return `200`. Public resolvers return no A record and
direct tailnet ingress times out. The generated bootstrap handoff is absent,
the Kubernetes bootstrap Secret is deleted, the bootstrap API token returned
`204` on revocation, and Sops retains only break-glass material plus the
least-privilege `svc-homelab-iac-authentik-config-manager` token. OpenBao
runtime values remain at `secret/platform/authentik`. This was the S1 boundary;
S2 subsequently changed Harbor authentication under the gates below.

### S2 — Direct Harbor human OIDC canary

**Observable result:** one local Authentik user completes MFA, receives Harbor
guest access through `harbor-readers`, and cannot push or administer; an
unbound user is denied before Harbor onboarding.

**RED:** create IaC assertions for exact client type, strict callback, signing
key, issuer mode, short token/session validity, minimal claims, flat groups,
Harbor certificate verification, empty admin group, and OIDC group membership
on `library`/`dockerhub`. The live acceptance must initially fail because
Harbor still reports `db_auth`.

**Minimum GREEN surface:**

- `homelab-iac/components/authentik/` owns local user metadata, flat groups,
  MFA/enrollment flows, signing-key selection, and application bindings.
- `homelab-iac/components/harbor-iam/` owns the strict confidential Harbor
  client, filtered group scope mapping, Harbor OIDC configuration, a bootstrap
  system robot, and an independent day-two state containing
  `harbor_project_member_group` resources with `role = "guest"`.
- Provider credentials arrive only through ephemeral environment variables.
  Authentik's client secret remains only in this component's encrypted state;
  it has no output. Harbor provider `insecure` is explicitly false.
- Global Harbor configuration and robot issuance retain the local `admin`
  bootstrap boundary. Routine project membership uses only
  `robot$homelab-iac-harbor-project-iam-manager`; its finite-lifetime,
  write-only credential is stored at
  `secret/platform/harbor/project-iam-manager` in OpenBao.
- `bin/harbor-project-iam` exchanges the dedicated exact-read AppRole, reads
  only that record, revokes the short-lived OpenBao token, and runs the day-two
  state without a human or Harbor administrator credential.
- Use automatic onboarding with a stable non-email username claim. Do not set
  `oidc_admin_group` in this slice.

Before auth-mode mutation, take a narrowly scoped consistent Harbor database
snapshot and export the sanitized auth configuration. This is a transactional
rollback artifact, not the deferred backup/HA design.

**Verification:** IaC Bats contracts, formatting, `terragrunt validate`, and an
encrypted plan with zero unintended destroys; Authentik discovery/JWKS; Harbor
"Test OIDC Server"; allowed-user MFA login; guest pulls; denied push/delete;
unbound-user denial; local-admin `/account/sign-in`. Confirm Cloudflare and
Cloudflare loss does not affect this private flow; from LAN, loss of Internet
connectivity must not affect it either. Authentik must report no Enterprise
license and no configured external identity source.

**Rollout:** Authentik core apply → Harbor client/apply with admin group absent
→ operator canary → reader group membership. **Rollback:** before first OIDC
onboarding, restore the prior auth configuration. After onboarding, keep local
admin active, disable the Authentik application binding, and restore the
pre-cutover Harbor database only if returning to `db_auth` is required.

**Configuration evidence (2026-08-31):** Harbor `2.15.2` reports `oidc_auth` with local
authentication retained, strict Authentik callback login succeeds, `erik` has
no system administration, and `harbor-readers` remains guest on `library` and
`dockerhub`. Authentik user, token, RBAC role, and RBAC group names now expose
their exact config-manager purpose. Harbor robot ID `7` has only project-list,
project-read, and member CRUD; its generation-2 credential authenticated the
membership import/update. The day-two membership, bootstrap Harbor IAM, and
OpenBao secret states each plan with zero drift. Existing memberships were
imported before old state ownership was removed; no live member was deleted.
This does not yet prove the denied push/delete, unbound-user,
Internet/Cloudflare-independence, or license/external-IdP gates; S2 remains open
until sanitized evidence records them.

#### S2R — Reviewed least-privilege and evidence correction

**Observable result:** the preflight classifies onboarded OIDC users truthfully;
the Harbor manager is limited to `library` and `dockerhub`; its bootstrap state
plans without receiving the stored robot value; and day-two membership reads
that value through a distinct exact-read OpenBao identity.

**RED:** desktop pytest reproduces Harbor 2.15's list/detail difference and
rejects a leaked OIDC CLI secret. IaC Bats rejects wildcard project membership,
day-two use of the broad OpenBao writer identity, generic AppRole variables, a mandatory
steady-state robot secret, and a wrapper that leaves AppRole credentials in the
Terragrunt environment.

**Minimum GREEN surface:** stream each non-administrator user detail through a
boolean-only filter without writing the raw OIDC CLI secret to disk; treat an
exact detail 404 as local and fail on other errors; change the
Harbor robot's wildcard block into two exact project blocks; make `secret_wo`
and its version null unless bootstrap input is present; fail closed on fresh
secretless creation and forbid in-place secret rotation; add exact publisher
and reader OpenBao policies/AppRoles with five-minute tokens and finite
SecretIDs; unset AppRole values after login; rotate their role/secret IDs
directly into encrypted Sops through the desktop entrypoint. Block Authentik
binding unless the target is a non-superuser service account, then rotate its
finite 90-day token.

**Verification:** focused desktop pytest and IaC Bats first; full owner checks;
zero-destroy plans for OpenBao foundation, Harbor bootstrap, and project
members; apply OpenBao before credential capture, then narrow Harbor and prove
the wrapper produces a zero-drift plan. Re-run the sanitized live preflight;
`erik` must report `oidc: true` and the migration blocker list must be empty.

**Rollout:** OpenBao policies/AppRoles -> encrypted Sops capture -> remove/import
the existing robot at the same Harbor ID under the secretless configuration
(state-only migration; stop unless the immediate plan is zero-destroy) -> Harbor
permission narrowing -> wrapper zero-drift plan -> preflight. **Rollback:**
restore the prior Harbor permission block only if exact scopes break Terraform;
retain the dedicated reader. To reverse the membership state split, import the
members only after restoring their prior bootstrap resource declarations (or
an exact temporary equivalent), verify the bootstrap plan, then state-remove
day-two ownership; never destroy either membership resource as the first
rollback action.

**Live evidence (2026-08-31):** robot ID `7` was re-imported under the
secretless configuration and its bootstrap wrapper plans with zero drift. Live
permissions contain only project-list plus member CRUD/project-read on
`library` and `dockerhub`. The day-two wrapper authenticates through the
exact-read AppRole and plans zero drift. The legacy writer no longer reaches
the Harbor record; the exact publisher and reader use five-minute tokens and
90-day SecretIDs, and recapture revoked prior accessors. Sops contains only the
four purpose-named AppRole fields, mode `0600`, with no embedded newline.
Authentik's config-manager token now expires after 90 days and its binding is
guarded by a blocking service-account/non-superuser precondition. The live
preflight reports `erik` as OIDC and no local non-administrator migration
blocker while retaining no raw per-user detail on disk.

### S3 — Privileged WebAuthn and break-glass

**Observable result:** privileged access requires direct membership in the
flat `harbor-admins` group and WebAuthn; normal reader access remains unchanged;
offline recovery works without Authentik OIDC, email, or Cloudflare.

**RED:** contracts fail until `harbor-admins` is flat, initially empty, bound to
a WebAuthn-required flow, and excluded from ordinary reader administration.
Live tests must show password/TOTP-only privileged login denied.

**Minimum GREEN surface:** enroll two independently held WebAuthn credentials
for the operator, verify Sops break-glass recovery, then enable the exact Harbor
admin-group setting. Keep Authentik superuser membership separate from Harbor
administration. The global/bootstrap Harbor provider continues using the local
admin credential, not an OIDC administrator session; routine project membership
continues through the dedicated project-IAM robot.

**Verification:** direct-member admin succeeds; similarly named group, nested
group attempt, reader, and password/TOTP-only privileged attempts fail; remove
one WebAuthn credential and prove the second; exercise local Authentik and
Harbor recovery without changing routine policy.

**Rollback:** clear Harbor's OIDC admin group and remove the application binding;
retain reader OIDC and local admin. Never weaken the global MFA flow as rollback.

### S4 — Fleet reader reconciliation and outage independence

**Observable result:** every pinned host has a distinct robot limited to
pulling `library` and `dockerhub`; only real consumers receive credentials; one
reader can be disabled and revoked without affecting another; Authentik outage
does not affect robot pulls or OpenBao AppRole.

**RED:** IaC contract asserts robot count equals the pinned fleet, every
permission is exact project `repository:pull`, no wildcard namespace exists,
and every secret path is unique. A fixture plan for a retiring host must first
fail because two-phase disable/removal is absent.

**Minimum GREEN surface:**

- `components/harbor-iam` derives system-level robots from the pinned fleet,
  with only the two exact project permission blocks. Use ephemeral
  `random_password`, Harbor `secret_wo`, and OpenBao `data_json_wo` in one
  encrypted unit, sharing only the ephemeral value during apply.
- Reader credentials have an explicit finite lifetime and an expiry warning
  before the planned overlap window; they never inherit Harbor's unlimited
  default duration.
- Store metadata/value at `secret/fleet/harbor/readers/<host>`. A nonsecret
  generation number triggers rotation. No secret output exists.
- Add one `disabled_hosts` set for two-phase retirement: first set
  `disable = true` and prove denial; only a later reviewed change removes the
  robot and OpenBao value after the host leaves the fleet snapshot.
- `desktop-nixos` adds a central map only for proven Harbor consumers and
  projects credentials through existing Sops/Vault-agent/bootstrap patterns.
  Hosts without a consumer receive no image or runtime change.

**Verification:** plan JSON permission/count assertions; one host pull canary;
cross-host metadata proves distinct IDs; denied push/delete/admin; temporary
disable/re-enable canary; Authentik scaled unavailable while robot pull and
OpenBao AppRole still succeed; restore Authentik before continuing.

**Rollout:** one reader canary → one real consumer projection → remaining robot
metadata → supported consumers in bounded host batches. **Rollback:** disable
new robots and restore prior consumer credentials. Never delete a robot or
OpenBao value in the same change that first disables it.

### S5 — `library-mirror` writer cutover

**Observable result:** the sole source-proven writer pushes and verifies a
versioned digest in `library`, cannot write another project or delete artifacts,
and the old shared credential is disabled after the cutover.

**RED:** Servarr and IaC tests fail while `harbor-mirror.sh` consumes the shared
`secret/home/harbor` robot and while no producer-specific project robot exists.
The negative live test must demonstrate that the candidate cannot delete.

**Minimum GREEN surface:** create one project-level `library-mirror` robot with
only `repository:pull` and `repository:push`, using the same ephemeral/write-only
Harbor-to-OpenBao path as readers. Store it at
`secret/home/harbor/writers/library-mirror`. Change only the Vault-agent render
feeding the existing mirror command; do not rewrite the working publication
script. Give the writer a shorter explicit lifetime than readers and alert
before its overlap window. Add an immutable version-tag rule after its RED test.

**Writer rollout:**

1. Create the new disabled writer and OpenBao record.
2. Enable it, render the new credential, push a disposable canary tag, and
   verify the returned digest.
3. Prove denied cross-project push, artifact delete, robot management, and
   policy changes.
4. Run the existing signed-source `harbor-mirror.sh` path for one real release;
   verify the consumer-visible digest.
5. Disable the old shared writer; observe one release window before deleting
   its value in a later change.

**Verification:** focused IaC/Servarr/desktop tests, exact Harbor permissions,
push/digest/denial canaries, and immutable-tag rejection. **Rollback:** before
old-writer revocation, switch the Vault-agent render back and disable the new
writer. After revocation, re-enable the old identity only through an explicit
break-glass apply; never broaden the new writer.

### S6 — Private projects and offsite fleet acceptance

**Observable result:** every declared LAN/tailnet consumer pulls through SWAG;
anonymous pulls and raw Harbor backend access fail; writer permissions remain
unchanged.

**RED:** dynamic Tailscale tests enumerate pinned hosts whose `tailscaleIp` is
non-null and fail for any such host unable to reach `swag:443`; LAN-only hosts
are covered by separate SWAG tests. Live tests currently show public project
pulls and LAN access to `:8085` succeeding.

**Minimum GREEN surface:** retain the existing wildcard Tailscale SWAG rule and
add fleet-derived policy tests rather than per-host duplicate ACL entries. Reuse
the OpenBao restricted-listener pattern with a dedicated SWAG-to-Harbor bridge,
then bind Harbor `:8085` only to that bridge. After every authenticated pull
passes, set `library` and `dockerhub` private through the Harbor component.

**Verification:** on-LAN and offsite Tailscale pulls by digest for every declared
consumer; DNS resolves to SWAG; trusted TLS and registry challenge; anonymous
401; direct LAN/tailnet/public backend denial; producer push still succeeds only
in `library`.

**Rollback:** make the affected project public if a missed consumer is found;
do not reopen the raw backend. Revert the dedicated bridge only if SWAG itself
cannot proxy after the prior configuration is restored.

### S7 — Second relying party and blue-green rotation

**Observable result:** Argo CD uses its own direct Authentik client and group
binding without changing Harbor access; OIDC and robot credentials rotate with
overlap, then the former identity is rejected.

**RED:** GitOps/IaC tests fail until Argo has a distinct strict client, exact
callback, local-admin fallback, and independent group. Rotation acceptance
fails while old and new identities cannot overlap.

**Minimum GREEN surface:** add Argo CD direct OIDC configuration without Dex and
retain the local admin. Parameterize only a nonsecret client/robot generation.
Rotation creates a replacement identity with a new name/ID and secret, updates
the consumer after the replacement passes, then disables and later deletes the
old identity. Do not rotate in place across two providers.

**Verification:** Argo allowed/denied/MFA/local-admin tests; Harbor claims and
roles unchanged; new client/robot succeeds before cutover; old succeeds during
overlap, then fails after disable. The secret audit asserts write-only robot and
OpenBao values are absent from decoded state, the unavoidable Authentik client
secret is sensitive and confined to its encrypted unit, and no credential is
present in outputs, plaintext plans, logs, or evidence.

**Rollback:** before old disable, point the consumer back to the old identity.
After disable, re-enable it only if still within the observation window;
otherwise generate another replacement. Additional Grafana, OpenBao, and
Dockhand clients require their own accepted slices.

### Cross-slice verification and completion

After each GREEN, run the focused owner test first, then the owner repository's
broader check. At the final gate run:

```text
homelab:         just test && just docs-check
homelab-gitops:  just test
homelab-iac:     bats tests/*.bats && tofu fmt -check -recursive && terragrunt hcl validate
desktop-nixos:   just check
servarr:         pytest -q machines/discovery/tests
live:            bin/homelab iam-acceptance
```

The last command remains prospective until its delegated owner commands exist.
Completion requires all feature bindings green, no unreviewed destroy in IaC
plans, no plaintext secret evidence, local break-glass proof, and explicit
rollback evidence for the active slice. Backup and HA planning starts only
after S1–S7 acceptance.

### `/ip` grill and CodeHero gates

Applied perspectives: security, reliability, architecture, tests,
compatibility, and operations. Performance is limited to capacity and resource
requests because fleet size is fixed; accessibility is not applicable because
no custom UI is built.

Accepted corrections:

- Replaced the impossible zero-state-secret claim with write-only fields where
  supported and isolated encrypted state for Authentik's provider limitation.
- Rejected nested privileged groups because Authentik inherits group rights.
- Kept Cloudflare outside the core path because its Authentik integration needs
  a public issuer.
- Added a pre-auth Harbor database snapshot because OIDC onboarding changes the
  rollback boundary.
- Chose blue-green client/robot rotation; in-place cross-provider secret changes
  create an unavoidable mismatch window.
- Reused the fleet-wide SWAG ACL instead of generating duplicate per-host rules.
- Reused existing GitOps, OpenBao write-only, Sops bootstrap, local-path
  PostgreSQL, and SWAG restricted-bridge patterns; no module or repository was
  added speculatively.
- Corrected list-user provenance through Harbor's per-user endpoint instead of
  treating an omitted field as a local-account assertion.
- Rejected wildcard Harbor member administration and the broad OpenBao writer
  for day-two reads; both now follow the authority-bound identity rule.
- Deferred a generic credential framework and automatic renewal scheduler; the
  existing rotation commands plus explicit 90/30-day gates cover the current
  single-controller scale.
