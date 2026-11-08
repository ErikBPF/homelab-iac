# Secret scanning: S7 delivery and verification

**Status:** source prepared and locally verified; remote exact-head checks and app review precede landing. GitOps producer has passed on published main before this enforcement consumer.

Owner: homelab-iac. The accepted security-remediation S7 scope adds automatic main-push, PR and main-only dispatch scanning, trusted failure notifications without findings, and public required-check enforcement. These explicitly supersede the original phase's notification and branch-protection exclusions. The [original plan](https://github.com/ErikBPF/homelab-iac/blob/47404a9/docs/behaviors/secret-scanning/plan.md) remains historical evidence; no accepted credential-rejection or privacy behavior is relaxed.

## Scanner boundary

Use full checked-out HEAD ancestry, read-only repository permissions, no persisted checkout credential, and the checksum-verified Gitleaks8.24.3 CLI. Native CLI scanning preserves merged-side and deleted history that the prior action's first-parent/unpaginated ranges could miss. Run the actual repository scan before any repository Python can modify its binary or policy.

Fixed scanner defaults and the immutable PR-base fingerprint list judge PRs. Manual dispatch fails for every ref except exact refs/heads/main before repository code. Main push and permitted manual runs therefore use their reviewed commit policy. Automatic PR scanning covers other branches. Replace the implicitly loaded source ignore file with that trusted snapshot without following symlinks. Explicit ignore-path alone is insufficient: this scanner also loads source/.gitleaksignore. Ignore inline suppression comments. A PR's new config, fingerprints, symlink or annotation cannot hide a new credential.

Two historical fingerprints remain reviewed legacy exceptions: a public release-signing fingerprint and an inert fixture password. In this producer history the first anchored UUID appears only in the158fccf fixture. It is also the verified public signing-key object ID used by the [provider3 consumer](https://github.com/ErikBPF/homelab-iac/blob/4362b4f623c2413ccf58a1e09ad97a365e388114/components/authentik/modules/openwebui-oidc/main.tf#L36) in successorPR166; its exception must be published before that real declaration lands, and commit fingerprints change on squash. The initial negative fixture itself committed an inert one-character-neighbor UUID at158fccf; that scalar is the second anchored exact-value exception with explicit synthetic provenance. Future negative neighbors are generated only at runtime and still fail. The historical second fixture exception can be removed after both stacked PR histories are squashed out of main; retain its provenance until then. No path, UUID class or genuine credential is exempted.

## Notifications and enforcement

Only failed trusted main pushes/manual runs enter the existing security webhook step. It sends the owner mention and workflow link with findings withheld. Missing webhook configuration cannot mask scanner failure. PRs, including forks and positive controls, never enter that step or receive its credentials. Scanner reports are not uploaded or posted.

Publish and observe exact producer jobs on main before applying required contexts: public IaC lint+secret-scan; public GitOps secrets. Preserve the independent app-review ruleset. The owner chose to keep Servarr private; GitHub Free cannot enforce its merge checks, so that limit remains explicit. No visibility/billing change occurs.

## Evidence and recovery

The [Gherkin contract](secret-scanning.feature) remains unautomated. `python3 tests/security-workflow-contract.py` runs real clean/leak/deleted-history and hostile-policy fixtures, squash/object-ID controls, actual notification scripts with stubbed transport and event/ordering assertions. `python3 tests/secret-scanning.py` retains ciphertext, exact-fingerprint, redaction and merged/deleted-history coverage without decryption. CI is the hosted rollout proof; local fixtures do not prove event scheduling.

New genuine findings block delivery. Correct verified false positives narrowly; never suppress unknown credentials for green CI. Recovery uses owner-reviewed source/policy changes while retaining effective scanning and independent review. No history rewrite or bypass of a failed check is implied.

Sources: [Gitleaks CLI](https://github.com/gitleaks/gitleaks/tree/v8.24.3), [additive ignore loading](https://github.com/gitleaks/gitleaks/blob/v8.24.3/cmd/root.go#L226-L245), [prior action implementation](https://github.com/gitleaks/gitleaks-action/blob/e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e/src/gitleaks.js).
