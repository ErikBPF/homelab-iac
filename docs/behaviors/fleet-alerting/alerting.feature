@contract @unautomated
Feature: Truthful fleet alerting and response
  The operator receives one safe, actionable signal for a real fleet condition
  and can distinguish workload failure from monitoring failure.

  Background:
    Given Kubernetes Grafana owns central alert evaluation and native Discord delivery
    And host and workload repositories own their signal producers and diagnostics

  Scenario: Report telemetry loss instead of invented workload failures
    Given named workload telemetry is absent or stale
    When Grafana evaluates workload availability
    Then one telemetry-control alert becomes active
    And named workload-down alerts do not become active from that missing identity

  Scenario: Remove a retired provisioned rule
    Given a rule and its metric producer are intentionally retired
    When the reviewed alert configuration is reconciled
    Then its UID is present in the provisioning deletion list
    And the rule is absent from Grafana's rule and active-alert inventories

  Scenario: Preserve a truthful incident during alert maintenance
    Given an active alert identifies a real failed job or control-plane drift
    When alert sources or routing are reconciled
    Then the alert remains visible until its owning condition recovers
    And no blanket silence or threshold extension hides it

  Scenario: Assign one notification owner per event class
    Given Grafana and Wazuh can both observe a security event class
    When notification ownership is reviewed
    Then exactly one system sends the operator notification for that class
    And the other system may retain evidence without sending a duplicate

  Scenario: Deliver safe firing and resolved notifications
    Given a staffed bounded drill uses an existing Grafana rule
    When the rule fires and then recovers
    Then native Discord receives one firing and one resolved notification
    And the payload contains only approved value-free evidence
    And retired Cleytin webhook routes receive nothing

  Scenario: Refuse to report monitoring unavailability as no alerts
    Given the Kubernetes API, Grafana, or Prometheus is unreachable
    When the operator requests current alert status
    Then the command reports the unavailable dependency
    And it does not report active=0
    And no credential value leaves its sanctioned runtime boundary

  Scenario: Close after stable observation
    Given source contracts, live inventory, delivery, and recovery drills pass
    When seven days of alert history are reviewed
    Then every remaining active alert has one owner and next action
    And no stale rule, duplicate notification, unsafe payload, or false workload diagnosis remains
