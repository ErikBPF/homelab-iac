# GitHub App installation leaves IaC (2026-11-26)

**Status:** complete in code; the app installation itself is suspended by the owner.
**Owner:** homelab-iac.

## What changed

`github_app_installation_repository.kindle-release-servarr` asserted that the Kindle release
GitHub App could reach the `servarr` repository. That resource calls
`GET /user/installations/<id>/repositories`, which only a **user-to-server** token can reach, so
the component kept an OAuth refresh token in the apply path. The refresh token expired, refreshes
began returning `bad_refresh_token`, and every merged-main apply since failed in `github/repos`
with `401 Requires authentication` — refusing the whole pass, LiteLLM units included.

An app-auth provider (`app_auth` with app id, installation id and private key) was tried and
removed again: installation tokens answer `403 Resource not accessible by integration` on that
user-facing endpoint, so it cannot work for this resource by construction. Along the way the
provider's `pem_file` field turned out to decode its **value**, not the path it names — a
behaviour that cost one apply cycle and is recorded here so nobody repeats it.

The resource now lives in the app's installation settings:

- PR #200 removed the resource, the app-auth provider and the app credential from the tree.
- PR #201 removed the resource declaration, its variable, output and configuration alias from
  `github/modules/repo`, which otherwise failed every plan with
  `Provider configuration not present / Re-add the provider configuration to destroy`.
- The state entry was forgotten with `terragrunt state rm` (no destroy, no GitHub change).
- `desktop-nixos` #572 removed the private-key handoff from the apply runner and the stale
  `github-app.pem` was deleted from `/var/lib/homelab-iac-main-apply/`.

## Current state

The owner **suspended the installation**. `servarr` was its only selected repository, so the
Kindle release workflow that published there has no installation token until the app is
reinstalled and re-selected.

`github/repos` still publishes `KINDLE_RELEASE_APP_ID` and `KINDLE_RELEASE_PRIVATE_KEY` into the
`kindle-dash` repository secrets, because that is how the release workflow mints its own token.
Both are inert while the installation is suspended.

## Consequences

- No app credential, PEM or OAuth refresh token is in the infrastructure apply path any more; the
  only GitHub credential there is the PAT in `secret/iac/github`.
- Re-granting the app access is a UI action under
  `https://github.com/settings/installations`, not an IaC change.
- The merged-main apply is still refused for an unrelated reason:
  `tailscale/acl` has drifted and that unit is in `IAC_APPLY_DENYLIST`, so it needs one manual
  apply before LiteLLM units (and the `ha-pqnld` / `voice-transcribe` aliases) land.
