# Proposal index

Last synchronized: 2026-08-01.

| Proposal | Current status | Remaining value | Delivery risk | Next gate | File coverage |
|---|---|---:|---:|---|---|
| [Fleet flake package-updater CI hardening](proposals/2026-07-31-flake-package-updater-ci-hardening.md) | Implemented; central App workflow active | Low | Low | Migrate the App token action from deprecated `app-id` to `client-id` before compatibility is removed. | `repos.json`, central runner workflow, three component updaters and CI gates |
| [Fleet security notifications](proposals/2026-07-24-fleet-security-notifications.md) | Implemented; failure alerts mention only the fixed Cleytin user | Medium | Low | Review alert usefulness and duplicates after the 30-day observation window. | Fleet GitHub workflows, `tests/security-notification-contract.sh`, repository Actions secrets |
