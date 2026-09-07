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
