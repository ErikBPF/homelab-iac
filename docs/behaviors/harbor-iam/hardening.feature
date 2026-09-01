@unautomated
Feature: Private Authentik identity and Harbor access for the managed fleet
  The operator wants a self-hosted human identity provider with no paid
  dependency while every managed host can pull and only explicit producers
  can publish.

  Background:
    Given desktop-nixos publishes the canonical fleet roster
    And homelab-iac consumes an exact pinned fleet snapshot
    And Authentik is the authoritative human OIDC provider
    And OpenBao owns runtime secret values
    And Authentik and Harbor are reachable through trusted private HTTPS

  Scenario: Operate required identity capabilities without a licensed service
    Given Authentik has no enterprise license
    And no external identity provider is configured
    When an approved local user authenticates with MFA to an OIDC application
    Then local users, groups, policies, claims, and OIDC remain available
    And no hosted or metered identity service is contacted

  Scenario: Give every approved human Harbor reader access
    Given an approved user belongs to the flat harbor-readers group
    When the user completes Authentik MFA and signs in to Harbor
    Then Harbor grants reader access to library and dockerhub
    And Harbor grants no push, delete, project, robot, or system administration

  Scenario: Reject an unapproved human identity
    Given a valid Authentik user has no Harbor application binding
    When the user attempts the Harbor OIDC flow
    Then Authentik denies authorization
    And Harbor creates no local user record

  Scenario: Harden the Harbor OIDC exchange
    Given Harbor has a confidential Authentik client
    When Harbor starts the authorization-code flow
    Then Authentik accepts only the exact Harbor callback
    And Harbor validates the trusted issuer, signature, audience, and certificate
    And only the required identity and filtered group claims are released
    And wildcard callbacks, implicit grants, and hybrid grants are unavailable

  Scenario: Distinguish OIDC users from migration-blocking local users
    Given Harbor's user list omits OIDC metadata
    And an onboarded user has OIDC metadata on the per-user endpoint
    When the sanitized IAM preflight inventories users
    Then the onboarded user is reported as OIDC
    And only a verified non-administrator local user blocks migration
    And OIDC CLI secrets do not appear in evidence

  Scenario Outline: Require phishing-resistant authentication for a privileged user
    Given a user belongs to <privileged_group>
    And the user has two independently held WebAuthn authenticators
    When the user attempts privileged authentication without WebAuthn
    Then Authentik denies the privileged session
    And email delivery and Cloudflare are not required for recovery

    Examples:
      | privileged_group |
      | authentik-admins |
      | harbor-admins    |

  Scenario: Map administration only from the exact flat group
    Given the Harbor OIDC client emits a filtered groups claim
    And harbor-admins has no parent or child groups
    When a direct harbor-admins membership passes the administration canary
    Then Harbor may grant administration to that exact group
    And a similarly named group grants no administration
    But before that canary Harbor grants no OIDC administrator

  Scenario: Keep machine authentication independent of human OIDC
    Given Authentik is unavailable
    When an existing fleet robot pulls an allowed Harbor artifact
    Then the pull succeeds
    And OpenBao AppRole consumers continue authenticating
    And a new human OIDC session fails closed

  Scenario: Name each automation identity by its authority boundary
    Given an unattended controller needs access to an identity or registry API
    When its standing machine identity is reconciled
    Then its name identifies the identity type, controller, target, and capability
    And it has a credential distinct from every other target
    And its permissions cover only the named target and operation
    And no human credential or vague generic service-account name is used

  Scenario: Reconcile Harbor membership without bootstrap administration
    Given the Harbor project-IAM robot is limited to library and dockerhub
    And a dedicated OpenBao AppRole can read only that robot credential
    When homelab-iac reconciles reader-group membership
    Then no human or Harbor administrator credential is used
    And no unrelated OpenBao record is readable or writable
    And the short-lived OpenBao token is revoked before Terraform runs

  Scenario Outline: Preserve independent break-glass administration
    Given Authentik OIDC is unavailable
    And the Sops-held break-glass material is recovered
    When the operator uses the <recovery_path>
    Then local administration succeeds for <service>
    And routine authentication is not downgraded

    Examples:
      | service   | recovery_path                         |
      | Authentik | Sops-backed local administrator path |
      | Harbor    | local database administrator path    |

  Scenario: Register every fleet member as a reader
    Given a host exists in the pinned fleet snapshot
    When Harbor fleet access is reconciled
    Then that host has one distinct Harbor robot identity
    And the identity can pull from library and dockerhub
    And the identity cannot push, delete, administer projects, or manage robots
    And a future project is not readable until explicitly added

  Scenario: Project credentials only to real consumers
    Given a fleet reader exists for a host
    And the host has no supported Harbor consumer path
    When host configuration is reconciled
    Then the credential remains in OpenBao without host projection
    And no appliance or host image changes merely to store an unused secret

  Scenario: Keep fleet credentials distinct and private
    Given two fleet hosts can pull the same artifact
    When their Harbor and OpenBao metadata are inspected without reading values
    Then they use different robot identities and secret records
    And each projected credential is readable only by its named consumer
    And no credential value appears in Git, logs, plans, tests, or evidence

  Scenario: Revoke a removed fleet host
    Given a host is absent from the newly accepted fleet snapshot
    When fleet access is reconciled
    Then its Harbor robot is disabled before its OpenBao value is removed
    And its former credential cannot pull
    And unrelated readers continue to pull

  Scenario: Admit a writer explicitly
    Given a named producer owns a named project and artifact convention
    When its writer access is accepted
    Then it receives a producer-specific robot with push and pull on that project only
    And it receives no delete, policy, project, or robot administration rights
    And its credential is stored outside fleet-reader and administrator records

  Scenario: Publish an immutable release
    Given an accepted producer has a writer credential
    When it publishes a versioned artifact
    Then it verifies the Harbor digest after push
    And consumers pin that digest
    And a later attempt to rewrite the accepted release tag is rejected

  Scenario Outline: Serve identity and registry only through trusted private ingress
    Given a LAN or tailnet client resolves <hostname> to SWAG
    When it accesses <service> on HTTPS port 443
    Then the trusted certificate and expected application response are returned
    And no dedicated backend listener or public Internet path exists
    And <service> is not exposed through a public Cloudflare tunnel

    Examples:
      | service   | hostname                                      |
      | Authentik | authentik.homelab.pastelariadev.com          |
      | Harbor    | harbor.homelab.pastelariadev.com             |

  Scenario: Reach Harbor from an offsite fleet host
    Given the host has a Tailscale identity and accepts approved routes and DNS
    And Discovery advertises the approved SWAG host route
    When the host pulls a private digest through the Harbor hostname
    Then policy permits the SWAG HTTPS path
    And the host robot authenticates the registry request
    And direct backend ports remain denied

  Scenario: Add another relying party without widening existing access
    Given an internal application has a distinct Authentik client and exact callback
    When its OIDC integration is accepted
    Then only its bound groups can authorize that application
    And its client secret is not reused by Harbor or another application
    And existing application bindings remain unchanged

  Scenario: Remove anonymous pulls safely
    Given every declared consumer passed an authenticated pull canary
    And robot and local-administrator rollback paths passed
    When library and dockerhub become private
    Then anonymous pulls fail
    And every declared reader still pulls its pinned artifact
    And writer permissions do not widen

  Scenario Outline: Rotate a generated credential
    Given a <credential_type> reaches its rotation gate
    When its replacement is reconciled through its owning component
    Then the new credential passes only its declared operation
    And the former credential fails
    And supported providers use ephemeral and write-only secret fields
    And no credential value appears in plaintext plans, outputs, logs, or evidence

    Examples:
      | credential_type       |
      | OIDC client credential |
      | Harbor robot credential |
