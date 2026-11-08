# OpenWebUI OAuth adoption and scanner merge gates

The OpenWebUI unit imports existing Authentik provider3. It does not create or replace an application, policy, user or client secret. The existing client ID is discovered from provider metadata. Nondefault one-hour token validity, hashed subject mode, flows, mappings and signing-key ID are preserved. Shared root encryption covers state and saved plans; treat both as secret-bearing.

## Owner rollout

Use `devenv shell`, then `just authentik-config-manager plan -out=<private-saved-plan>`. The wrapper resolves the existing `svc-homelab-iac-authentik-config-manager` credential from dedicated OpenBao `secret/iac/authentik-config-manager`, revokes its 300-second reader token, then delegates to the provider3 unit. It verifies the stored identity and never prints the credential, full state or full plan. Bootstrap role/SecretID fields live encrypted in the owner `.env.sops`; the owner dotenv loader supplies them. Reader SecretIDs expire after90days and need deliberate renewal. No human credential or database token recovery is used.

From the repository root, use `just authentik-config-manager plan -out=<private-saved-plan>` and `just authentik-config-manager apply <private-saved-plan>`. Keep private plan/log artifacts outside Git with mode0600. Review a sanitized address/action summary: only provider3 import and addition of the strict HTTPS callback are expected. Any replacement, secret change, application change, flow/mapping change or unrelated change blocks apply. Apply only the reviewed saved plan.

Observe both registered callbacks before the linked GitOps consumer switches to HTTPS. Preserve the old callback until an authenticated HTTPS login and effective application URL pass. Then remove the HTTP compatibility entry in a follow-up plan/apply and repeat login. Stop on failure; retain both callbacks and revert the consumer. Import is not permission to replace the provider.

The unit stays excluded from unattended drift and automatic apply until credentials, adoption and zero-diff runtime checks are verified. Do not add it to the monitored fixture as part of source preparation. Module `tofu init -backend=false` and `tofu validate` passed without runtime credentials. The Bats contract preserves identity/configuration boundaries; it does not prove live OAuth login.

## Scanner producers and consumers

The CI secret-scan job uses a checksummed Gitleaks CLI, full HEAD ancestry and credential-free read-only checkout. Push/main, PR and dispatch events run it. Only trusted non-PR failures enter the value-free security notification step. Missing webhook configuration does not mask failure. Real disposable scanner fixtures and stubbed notification transport run in `tests/security-workflow-contract.py`; the existing ciphertext/exact-fingerprint tests remain.

Required checks add `secret-scan` for public IaC and `secrets` for public GitOps, preserving existing protection and review rulesets. Publish and observe the exact producer jobs on main before applying the reviewed GitHub policy plan. Private Servarr on GitHub Free remains unenforceable until the account owner changes the plan; neither visibility nor billing is changed here.

Grant types are Optional+Computed in provider2026.5.1 and deliberately omitted so import retains the existing set. A configured empty list could remove required code/refresh grants; the adoption contract rejects that. The observed empty logout URL remains explicitly preserved; its schema is optional, not computed. A reviewed live plan still must prove only import and redirect addition. Scanner policy must land through the preceding reviewed S7 change before dependent provider content; PRs trust immutable base fingerprint policy, never their own new suppressions.

The bootstrap store unit owns only one write-only credential value, an exact-path reader policy and its AppRole. The existing service credential was copied once from the sanctioned owner just/Sops lookup; it was not rotated. Its legacy Sops entry remains for existing Harbor bootstrap callers, which are outside this wrapper change. Do not place management tokens in the workload Authentik runtime path. Routine OAuth commands resolve their credential from OpenBao. The write-only version must increment for any later credential rotation.
