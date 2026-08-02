# Homelab ecosystem instructions

This is a coordination repo, not a monorepo.

- Cross-repo decisions and audits live here.
- Implementation belongs to the repository named in `repos.json`.
- Any change under `docs/proposals/` must update
  `docs/proposal-index.md` in the same change. Keep its status, remaining-value,
  delivery-risk, next-gate, and file coverage current.
- Keep `references/repos/` as gitignored local symlinks.
- Never make a consumer read another working tree during build or deployment.
- Publish and pin artifacts; runtime Vault access is the only sanctioned live
  cross-repo dependency.
- Land changes leaf-first, then update consumers, then deploy.
- Root commands may delegate to component commands; never duplicate their
  deployment implementation.

## Local secret handoff

- Pass secrets to Codex only through a purpose-named `*.secrets.json` file in
  the repository root; never paste secret values into chat.
- Keep the JSON minimal, set mode `0600`, and rely on the repository-wide
  `*.secrets.json` ignore rule.
- Codex must not print secret values. Consume only the requested keys, then
  delete the handoff file after the secret reaches its sanctioned store.

## Ownership

- `homelab-iac`: Terraform-managed infrastructure and external/platform control
  planes, including LiteLLM API resources. It does not own workload lifecycle,
  model training, prompts, or secret values.
- `desktop-nixos`: hosts, fleet metadata, NixOS, and cluster substrate.
- `servarr`: household compose workloads and their runtime lifecycle.
- `homelab-gitops`: lab Kubernetes workloads.
- Vault: runtime secret values. Sops: root-of-trust and host/build/bootstrap
  secrets.
