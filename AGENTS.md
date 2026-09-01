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

## Development workflow skills

Reusable workflow skills are installed declaratively by `desktop-nixos`.
Invoke them as `$name` in Codex or `/name` in slash-skill harnesses.

- `pl`: ground and conceptualize an idea, run bounded party elicitation,
  build its mental map, and write the BDD `.feature` contract.
- `ip`: turn accepted behavior into grilled vertical
  RED-GREEN slices with ownership, verification, rollout, and rollback.
- `rv`: review and revise plans, documents, or code; apply verified correctness
  and conformance fixes, simplify, then rerun relevant checks.
- `codehero`: independent security and other risk-focused review perspectives
  used during planning, plan grilling, and `rv`.
- `party`, `map`, `grill`: reusable elicitation, decision-mapping, and
  pressure-testing primitives orchestrated by `pl` and `ip`.

A `.feature` file is a behavior contract. Call it an automated test only when
its scenarios are bound to runnable steps and observed failing before the
implementation. Small documentation or wiring changes may start at the first
applicable workflow gate; do not invent tests or ceremony.

## Local secret handoff

- Pass secrets to Codex only through a purpose-named `*.secrets.json` file in
  the repository root; never paste secret values into chat.
- Keep the JSON minimal, set mode `0600`, and rely on the repository-wide
  `*.secrets.json` ignore rule.
- Codex must not print secret values. Consume only the requested keys, then
  delete the handoff file after the secret reaches its sanctioned store.

## Machine identity naming

- Name standing nonhuman identities as
  `<identity-type>-<controller>-<target>-<capability>`. Keep a product-required
  prefix such as Harbor's `robot$`, then apply the remaining segments.
- Use a separate identity and credential for each target trust boundary. Never
  use a human credential for unattended work.
- Reject vague standing names such as `automation`, `robot`, `service-account`,
  or a bare repository name. Fixed upstream break-glass users are exempt.
- Examples: `svc-homelab-iac-authentik-config-manager` and
  `robot$homelab-iac-harbor-project-iam-manager`.

## Ownership

- `homelab-iac`: Terraform-managed infrastructure and external/platform control
  planes, including LiteLLM API resources. It does not own workload lifecycle,
  model training, prompts, or secret values.
- `desktop-nixos`: hosts, fleet metadata, NixOS, and cluster substrate.
- `servarr`: media workloads and temporary legacy Compose owners pending a
  verified Kubernetes cutover.
- `homelab-gitops`: non-media home-services and lab Kubernetes workloads.
- Vault: runtime secret values. Sops: root-of-trust and host/build/bootstrap
  secrets.
