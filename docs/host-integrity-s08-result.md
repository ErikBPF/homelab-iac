# S08: scoped drift result

The user selected execution of the IaC track. The accepted S08 packet asks for
bounded detection and delivery results without changing adopted scope or apply
authority. This change adds an optional private machine result to the existing
script; human output and the current Discord notifier remain in place.

`DRIFT_RESULT_FILE` requests an atomically replaced mode-0600 JSON document:
`schemaVersion: 1`, `sourceRevision`, `scopeSha256`, `outcome`, `notification`.
Outcomes are `clean`, `drift`, and `error`; exits remain 0, 2, and 1 respectively.
Notification is `not-required`, `delivered`, `failed`, or `not-configured`.
`delivered` means the existing HTTP request succeeded, not that a person received
or read it. Failed delivery never changes detected drift into clean coverage.

The scope digest hashes the existing `tests/fixtures/drift-monitored-units.txt`;
that fixture and the exclusion filters are unchanged. The immutable consumer
supplies `DRIFT_SOURCE_REVISION`; direct checkouts can use their Git HEAD. No
provider lines, plan contents, credentials, or webhook URLs enter the result.
The existing state-passphrase propagation is exercised with a synthetic value.

The existing eight Bats contracts passed before the new result test failed with
`structured result not published`. After implementation all nine tests passed,
including clean/drift/provider failure, HTTP success/failure, missing notifier,
private permissions, exact scope identity, and absence of plan/credential data.
Tests ran with an empty inherited environment and stubbed Terragrunt/curl; no
provider, live drift plan, apply, or notification was executed. `git diff --check`
passed. Session RED/GREEN logs are `/tmp/s08-red.log` and `/tmp/s08-green.log`.

S09 must pin the published S08 revision before landing and validate result identity
against its pinned fixture. A missing result is a lifecycle failure, never clean.
Publication and independent review remain coordinator responsibilities. Rollback
restores the prior script/pin; it does not roll back infrastructure or alter scope.
