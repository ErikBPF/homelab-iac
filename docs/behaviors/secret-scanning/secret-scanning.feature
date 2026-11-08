# Unautomated behavior contract; runnable CLI regression: tests/secret-scanning.py.
Feature: Reject secrets before infrastructure changes land
  Scenario: Scan a clean change without decrypting secrets
    Given a clean repository containing SOPS ciphertext
    When its committed history is scanned
    Then the scan passes without decrypting the ciphertext

  Scenario: Reject a leaked credential even after deletion
    Given a credential was committed and then deleted
    When its committed history is scanned
    Then the scan fails
    And the credential value is absent from diagnostic output

  Scenario: Limit finding exposure
    When pull request or main branch CI scans secrets
    Then the job has read-only repository access
    And no findings are uploaded, commented, or sent to a webhook

  Scenario: Scan automatically without PR-controlled suppression
    When a pull request, main push or main-branch manual dispatch scans committed history
    Then fixed default rules and the trusted policy snapshot judge the change
    And PRs use their immutable base while main runs use the reviewed commit
    And PR-local config, ignore files, symlinks and inline comments cannot hide a new credential
    And repository code executes only after the verified scanner

  Scenario: Notify only trusted scan failures without findings
    When a main push or manual scan fails
    Then the security webhook receives only a workflow link and owner mention
    And a missing webhook does not mask the failed scan
    But a pull request never enters the webhook step

  Scenario: Enforce published public scanner jobs
    Given each producer succeeded on its published main revision
    When the reviewed GitHub policy is applied
    Then public IaC requires lint and secret-scan and public GitOps requires secrets
    And the independent app-review ruleset remains enforced
    And private Servarr remains private with enforcement blocked by GitHub Free

  Scenario: Reject manual scans of unreviewed refs
    When manual security scanning targets a feature branch or a tag
    Then the job fails before repository code executes
    And no security notification is sent
    And the contributor must use automatic PR scanning
