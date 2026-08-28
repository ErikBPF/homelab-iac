@contract @unautomated
Feature: Bounded multi-user contextual graph canary
  Operators can test relationship-aware recall without replacing source
  authority, leaking private data, or retaining an unproven stateful service.

  Background:
    Given Git and original publishers remain authoritative
    And Vault owns runtime secret values
    And Cognee uses only the reviewed synthetic fixture and local LiteLLM routes

  Scenario: Release only a validated immutable deployment
    Given the Cognee image and manifests are ready for review
    When the operator considers the first manual synchronization
    Then the image is referenced by a verified signed digest
    And full manifest validation passes
    And every required runtime secret path exists without exposing a value

  Scenario: Exclude unsafe inputs and egress
    Given the fixture contains a secret-canary file and excluded paths
    When Cognee ingests the reviewed fixture
    Then no excluded content appears in relational, vector, graph, cache, or result data
    And network traffic reaches only cluster dependencies and the approved LiteLLM address

  Scenario: Isolate private and shared datasets
    Given two authenticated users own separate private datasets
    And one dataset is deliberately shared read-only
    When each user reads, writes, deletes, searches, or probes those datasets
    Then private datasets remain invisible to the other user
    And the shared user can read but cannot write or delete
    And raw graph queries remain unavailable

  Scenario: Preserve derived state across one controlled restart
    Given the synthetic datasets were ingested successfully
    When Cognee, PostgreSQL, and FalkorDB complete one controlled restart
    Then users, ACLs, records, vectors, graph relationships, and provenance match
    And each dataset resolves to its intended Falkor graph and vector handlers

  Scenario: Refresh stale and deleted source context
    Given the fixture contains contradictory revisions and a deleted item
    When its commit-stamped dataset is refreshed
    Then current answers cite the current path and commit
    And stale and deleted content is absent from accepted results

  Scenario: Compose knowledge scopes deterministically
    Given a private session and active repository branch
    And homelab-global, related versioned package docs, and knowledge-global exist
    When the agent asks a repository-scoped question
    Then datasets are searched in session, branch, homelab, package, global order
    And every result retains its dataset, source, revision or version, and ingestion time
    And contradictory lower-precedence evidence remains visible

  Scenario: Gate unsupported Cognee upgrades locally
    Given Cognee 1.5.3 is stable
    And Falkor adapter 0.4.0 declares cognee 1.4.2 exactly
    When the local compatibility canary evaluates the newer pair
    Then the supported 1.4.2 pair remains the deployment baseline
    And the newer pair cannot publish or sync until handler, ACL, ingestion, search, and deletion checks pass

  Scenario: Retain only measurable retrieval value
    Given the source-backed baseline and Cognee use the same fixed questions and scoring
    When warm retrieval is measured at one and three authenticated users
    Then Cognee improves at least three relationship questions without regressing exact questions
    And warm retrieval p95 is at most 5 seconds
    And end-to-end p95 is at most 15 seconds
    And no unauthorized result, mutation, existence leak, or 5xx occurs

  Scenario: Restore one logically consistent service
    Given writes stop before PostgreSQL and FalkorDB are backed up under one run identifier
    When the backup set is restored into disposable persistent volumes
    Then counts, ACLs, searches, graph relationships, dimensions, and provenance match
    And the ACL negative cases still pass

  Scenario: Delete a failed canary
    Given any security, correctness, value, latency, or restore gate fails
    When the operator closes the canary
    Then ingestion stops and Cognee scales to zero
    And the Application, namespace, identified PVCs, Vault credentials, and LiteLLM access are removed
    And only sanitized benchmark evidence remains
