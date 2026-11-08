# Secret scanning: plan and verification

**Status:** Implemented; real-scanner regressions and full-history scan pass.
Independent review also rejected a deleted secret from merged side-branch history.

Owner: homelab-iac. Destination: PR and main CI reject committed secrets,
including secrets deleted in later commits. Trivy remains the IaC scanner.

Planning exchange (bounded local perspectives): operator wants a failing gate;
security requires redacted output and no finding publication; implementer
prefers the existing fleet action. Source review rejected that action because
its first-parent/no-merges ranges and unpaginated PR commit query can miss
history. Use the native CLI with a release version and archive SHA256, matching
the existing Terragrunt installer. No new service, token, or notification.

Decision map: full checkout history -> checksum-verified scanner -> redacted
blocking scan. No decryption, secret access, history rewrite, broad allowlist,
or branch-protection administration. Exact historical false-positive
fingerprints are reviewed exceptions; they never exclude future content.

Contract: [secret-scanning.feature](secret-scanning.feature) is unautomated
Gherkin. The independent CLI regression runs in `tests/secret-scanning.py`;
no Cucumber dependency or new Bats test.

Implementation slice: first run real Gitleaks against synthetic clean history
and SOPS ciphertext, then a synthetic leak and deletion. Require exit 0/1/1
and no credential in captured diagnostics. Before wiring CI, the repository
has no Gitleaks gate; full-history scan fails on two verified false positives.
Add one isolated CI job with contents:read, full checkout, disabled checkout
credential persistence, checksum verification and native `gitleaks git
--redact`. Keep regression in that job. No report files or external publication.

Grill: scanning only working files misses deleted leaks; action ranges miss
merge-side history. Full reachable history resolves both. Two historical
findings are a public signing fingerprint and a literal fixture-only password;
ignore only their exact commit fingerprints. New genuine findings block CI.
Do not decrypt SOPS to improve scanner coverage.

Verification: `PATH=/path/to/pinned/gitleaks:$PATH python3 tests/secret-scanning.py`,
`gitleaks git --redact --no-banner .`, existing CI contracts and workflow lint.
The fixture test checks CLI behavior, not hosted event scheduling or runner
availability; GitHub CI is the rollout gate. Revert the CI job and its reviewed
fingerprints to roll back. Existing Trivy and lint jobs remain independent.

Sources: [Gitleaks CLI](https://github.com/gitleaks/gitleaks/tree/v8.24.3),
[action scan implementation](https://github.com/gitleaks/gitleaks-action/blob/e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e/src/gitleaks.js).

## S7 continuation supersedes original exclusions

The accepted security-remediation S7 scope now includes automatic push/main, PR and dispatch scans, value-free trusted failure notifications, and producer-before-consumer public required checks. The original “no notification” and “no branch-protection administration” exclusions above are historical and superseded for this continuation only. Findings remain withheld; PRs receive no webhook. Servarr remains private with enforcement unavailable on GitHub Free.

Run the real scan before any repository Python. Use explicit fixed defaults, immutable PR-base fingerprint exceptions, symlink-safe replacement of the implicitly loaded source ignore file and disabled inline suppression. The workflow contract reproduces hostile local config, new fingerprints, inline comments and symlinks. The verified Authentik signing-key object UUID receives a single anchored secret-value exception in trusted scanner configuration; commit-pinned exceptions would break on squash. A squash fixture permits that exact public identifier and rejects another value. No whole-path, UUID-class or credential exception is introduced.

`python3 tests/security-workflow-contract.py` exercises these boundaries with the checksummed CLI and stubbed notifications. Publish successful producer contexts on main before applying their enforcement consumer. Existing review rulesets stay intact. These new event/policy assertions refine the original source contract without claiming the Gherkin is an automated integration test.
