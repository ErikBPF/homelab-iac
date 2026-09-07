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
