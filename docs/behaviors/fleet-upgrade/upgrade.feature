@contract @unautomated
Feature: Safe fleet input upgrades
  The operator can update a reviewed flake candidate without activating an
  unbuilt, oversized, or unhealthy generation across multiple hosts.

  Background:
    Given fleet metadata identifies every managed NixOS host and its role
    And the candidate starts from a clean published revision

  Scenario: Refuse to replace an operator-owned lock change
    Given flake.lock is already modified
    When the operator prepares an upgrade candidate
    Then preparation fails before changing flake.lock
    And the existing lock content remains unchanged

  Scenario: Build only the candidate's affected hosts
    Given the changed inputs affect a known subset of host closures
    When the operator prepares the candidate
    Then repository checks and every affected host closure pass before activation
    And an unaffected host is recorded without being rebuilt

  Scenario: Block a candidate that cannot retain a known-good boot
    Given an affected host's projected ESP cannot hold the candidate generation
    And one known-good generation
    And 25 percent reserve
    When the operator runs the activation preflight
    Then activation is blocked for that host
    And the host is routed to its ESP migration gate

  Scenario: Keep switch-all limited to config-only changes
    Given the candidate changes flake.lock
    When the operator requests switch-all
    Then the command refuses the rollout before activating any host

  Scenario: Stop the sequential rollout on failed verification
    Given the candidate and every affected closure passed preflight
    And one host at a time is selected from the reviewed rollout order
    When the current host fails revision, failed-unit, reachability, service, or ESP verification
    Then no later host is activated
    And the operator is shown the previous-generation or fix-forward rollback path

  Scenario: Record a deliberate exclusion
    Given an affected host cannot enter the current maintenance window
    When the operator excludes that host
    Then the evidence records the reason and catch-up window
    And the proposal remains open until the host catches up or receives a reviewed exception

  Scenario: Finish with value-free rollout evidence
    Given every included host passed post-activation verification
    When the rollout finishes
    Then the evidence records candidate revision, host revision, activation mode, result, and timestamp
    And it contains no credential or secret value

  Scenario: Reject a host kernel that fails after boot blessing
    Given Kepler booted and blessed the Linux 7.2 candidate
    And retained journals show repeated kernel faults and unexpected reboots under normal workload
    When the operator evaluates candidate acceptance
    Then the Kepler host candidate is rejected
    And Kepler is restored and pinned to the known-good Linux 6.18 host kernel
    And unattended Kepler activation and reboot remain suspended while the incident is open

  Scenario: Evaluate host and guest kernels independently
    Given a Linux 7.x kernel is healthy on another physical host or a MicroVM guest
    When the operator evaluates a Kepler host kernel candidate
    Then that unrelated success does not authorize the Kepler host candidate
    And each physical-host and guest role retains its own evidence and decision

  Scenario: Keep crash recovery separate from rollback
    Given Kepler lockup detection panics and reboots an unresponsive blessed generation
    When the host returns and persistent evidence is available
    Then the recovery is recorded without accepting the candidate
    And boot counting is not claimed to roll back a generation that failed after blessing
    And no automatic boot selection is added without a disposable loop-safety proof

  Scenario: Soak a future Kepler host kernel under its real workload
    Given the exact candidate and previous generation are retained
    And staffed console or Home Assistant tomada_kepler power recovery is available
    When Kepler runs the candidate with MicroVM virtiofs, ZFS, GPU, and Kubernetes workloads
    Then one boot ID remains unchanged for at least 60 minutes
    And no kernel oops, panic, RCU stall, failed required unit, or lost GPU or cluster readiness appears
    And the candidate remains under observation for 24 hours before acceptance

  Scenario: Distinguish no alerts from an unavailable monitoring plane
    Given Grafana and Prometheus are owned by the Kubernetes monitoring deployment
    When the operator requests current alert status
    Then the read-only recipe queries the Kubernetes-owned Grafana path
    And an unreachable Kubernetes API, Grafana, or Prometheus is reported as unavailable
    And only a successful empty response is reported as active=0
    And no credential value leaves its sanctioned runtime boundary

  Scenario: Detect Kepler monitoring loss outside Kepler
    Given Kubernetes monitoring and every cluster node share the Kepler physical host
    And Vanguard has an independent webhook and dead-man timer
    When a Kepler-owned readiness endpoint fails for the configured threshold
    Then Vanguard delivers one value-free external incident
    And recovery resets the dead-man without deploying another monitoring stack

  Scenario: Branch diagnosis after the rollback observation
    Given Kepler runs Linux 6.18 with the current userspace, guest kernels, and workload for 24 hours
    When the operator reviews the observation
    Then stability keeps Linux 7.2 quarantined pending a bounded reproducer
    But another crash opens one-variable-at-a-time isolation of MicroVM autostart, RAM, virtiofs, ZFS, and GPU paths
