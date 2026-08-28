@unautomated
Feature: GitOps ownership of non-media homelab workloads
  The operator wants one declarative Kubernetes owner for non-media services
  while the Servarr repository remains focused on the household media system.

  Background:
    Given the Kepler Kubernetes cluster is reconciled from reviewed Git desired state
    And host and cluster substrate remain owned by desktop-nixos
    And runtime secret values remain owned by Vault

  Scenario Outline: Classify the first migration wave
    Given the service is <service>
    When its desired-state lane is selected
    Then its lane is <lane>
    And its target runtime is Kubernetes

    Examples:
      | service            | lane          |
      | Immich             | home-services |
      | Karakeep           | home-services |
      | Changedetection    | home-services |
      | Langfuse           | homelab       |
      | central monitoring | platform      |
      | Wazuh              | platform      |

  Scenario: Keep the media system in Servarr
    Given Plex, Jellyfin, downloaders, arr applications, and Unpackerr form the media system
    When repository ownership is evaluated
    Then Servarr remains their desired-state and runtime owner
    And they are not migrated for repository symmetry

  Scenario: Reconcile platform capabilities before workload stacks
    Given a clean cluster rebuild
    When the GitOps applications are reconciled
    Then storage, ingress, and runtime secret projection become ready before dependent workloads
    And platform services become ready before homelab and home-services workloads

  Scenario: Restrict each GitOps lane to its declared boundary
    Given platform, homelab, and home-services use separate Argo project policies
    When an application requests a source, destination, namespace, or cluster-wide resource
    Then the request is allowed only when its lane explicitly authorizes it
    And wildcard authority is not granted as a convenience

  Scenario Outline: Create fresh durable application state
    Given legacy Compose state exists for <service>
    When <service> is installed in Kubernetes
    Then no legacy application data is imported
    And fresh Kubernetes persistence is created where the service requires durable state
    And the legacy files and volumes remain untouched

    Examples:
      | service         |
      | Immich          |
      | Karakeep        |
      | Changedetection |
      | Langfuse        |
      | monitoring      |
      | Wazuh           |

  Scenario: Admit a workload only when the cluster has capacity
    Given a workload declares resource requests and limits
    When its reviewed release is considered for synchronization
    Then it is synchronized only if worker capacity and observed headroom admit it
    And an admission failure leaves the existing Compose service unchanged

  Scenario: Run Immich without unavailable cluster hardware
    Given the Kubernetes workers have no GPU access
    When Immich is accepted for the first migration wave
    Then its core user journey works without GPU acceleration
    And GPU enablement remains a separate substrate decision

  Scenario: Preserve host-level observability
    Given central monitoring runs inside Kubernetes
    When the entire Kubernetes cluster becomes unavailable
    Then an out-of-cluster signal reports the outage
    And host collectors continue without requiring device access from application pods

  Scenario: Re-establish Wazuh trust after a fresh installation
    Given the Kubernetes Wazuh installation has fresh credentials and certificates
    When one host agent is enrolled as a canary
    Then its security events become visible in the new Wazuh backend
    And remaining agents are not moved until the canary passes

  Scenario: Cut over one service to one runtime owner
    Given the Kubernetes replacement passes secret, persistence, dependency, probe, ingress, and user-journey checks
    When the operator accepts its cutover
    Then its Compose owner is disabled
    And Kubernetes becomes its only active workload reconciler
    And unrelated services from the same Compose file remain active
    And the established service name reaches the Kubernetes replacement

  Scenario: Reconcile the same desired state repeatedly
    Given a service is healthy at an exact reviewed revision
    When that revision is reconciled again
    Then no duplicate runtime owner is created
    And its credentials and healthy persistent claims are retained

  Scenario: Roll back runtime ownership without synchronizing state
    Given a migrated service fails after cutover
    When the operator invokes the approved rollback
    Then the previous Compose owner may be re-enabled
    And no data is copied or synchronized between the two runtimes

  Scenario: Contain GitOps changes while the deployment branch is unprotected
    Given the deployment branch lacks enforced protection
    When a desired-state revision is selected
    Then synchronization requires an exact reviewed revision and a manual operator action
    And automated pruning, self-healing, and directory discovery remain disabled

  Scenario: Keep lifecycle mechanisms within repository boundaries
    Given a non-Kubernetes workload remains during a later migration wave
    When its desired state is reconciled
    Then its desired state remains in the GitOps host lane
    And the host uses the existing desktop-nixos activation mechanism at an exact revision
    And Argo CD does not connect to the host to manage its lifecycle
