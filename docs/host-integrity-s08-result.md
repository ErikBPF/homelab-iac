# S08: scoped drift result

The user selected execution of the IaC track. The accepted S08 packet asks for
bounded detection and delivery results without changing adopted scope or apply
authority. This change adds an optional private machine result to the existing
script; human output and the current Discord notifier remain in place.

`DRIFT_RESULT_FILE` requests an atomically replaced mode-0600 JSON document:
`schemaVersion: 1`, `sourceRevision`, `scopeSha256`, `outcome`, `notification`.
Outcomes are `clean`, `drift`, and `error`; exits remain 0, 2, and 1 respectively.
Notification is `not-required`, `delivered`, `failed`, `not-configured`, or
`unknown`. An interrupted run can publish `error` with `unknown` when a webhook
was configured but delivery did not complete; it must never count as healthy.
Signal termination retains its signal exit status, outside the normal 0/2/1 mapping.
`delivered` means the existing HTTP request succeeded, not that a person received
or read it. Failed delivery never changes detected drift into clean coverage.

The scope digest hashes the existing `tests/fixtures/drift-monitored-units.txt`;
that fixture and the exclusion filters are unchanged. The immutable consumer
supplies `DRIFT_SOURCE_REVISION`; direct checkouts can use their Git HEAD. A
revision that cannot be resolved to 40 lowercase hexadecimal characters is
published as `unknown`; identity-validating consumers must reject it. No
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
against its pinned fixture and match the process exit to the outcome. The producer
removes the previous result after entering its checkout, before planning, and
aborts if removal fails. Callers MUST also remove any previous result before their own bootstrap
and script invocation, serialize runs sharing a result path, and reject results
when invocation fails. This covers failures before the producer can execute;
existence alone is never evidence of a completed run. SIGKILL cannot run the EXIT
trap and therefore leaves no result. A missing result is a lifecycle failure,
never clean.

PR176 independent review identified undocumented sentinels and stale success after
SIGKILL. A new offline regression first failed with `killed plan retained previous
clean result`, then passed after early removal. It runs clean followed by both
SIGKILL and SIGTERM during a stubbed plan, asserting absent output for SIGKILL and
`error`/`unknown` notification/revision for SIGTERM. All ten Bats tests passed;
receipts: `/tmp/s08-review-red.log`, `/tmp/s08-review-green.log`. No live commands
or notifications were used. An independent reviewer reproduced all ten tests
with an empty inherited environment and found no remaining material issue.

Publication and independent review remain coordinator responsibilities. Rollback
restores the prior script/pin; it does not roll back infrastructure or alter scope.
