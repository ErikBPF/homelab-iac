# Proposal index

Last synchronized: 2026-07-31.

| Proposal | Current status | Remaining value | Delivery risk | Next gate | File coverage |
|---|---|---:|---:|---|---|
| [Fleet flake package-updater CI hardening](proposals/2026-07-31-flake-package-updater-ci-hardening.md) | Partially deployed; central App canary blocked by private Actions billing | Medium | Medium | Restore private Actions billing or approve a runner/visibility change, re-enable the central workflow, then rerun the OpenCode canary. Retire component schedulers only after it passes. | `repos.json`, central runner workflow, three component updaters and CI gates |
