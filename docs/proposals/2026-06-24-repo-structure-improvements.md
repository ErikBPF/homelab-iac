# Repository Structure Improvement Proposal

**Status:** In progress — **Phase 0 done (2026-06-27):** dendritic contract at
`docs/reference/dendritic-contract.md` + `just structure-check` (report-only;
0 hard violations on the current tree, 4 large-file advisories). Phases 1–6 open.
**Audience:** Maintainers of `desktop-nixos`
**Post-read action:** Choose which structural cleanup phases to implement, in order, without changing host behavior accidentally.

## 1. Executive summary

The repository has already completed the important part of the dendritic migration: many small files register named modules into `flake.modules`, and hosts compose those modules explicitly. The current structure is workable and should not be replaced with a large aggregator tree.

The next improvement should be a tightening pass:

1. Make the dendritic contract explicit so new files follow the same shape.
2. Separate flake control-plane modules from NixOS and Home Manager leaves.
3. Standardize module naming and host anatomy.
4. Split the few very large feature modules by user-facing boundary.
5. Move operational and ignored local-state material out of the visual path.
6. Add cheap structural checks so drift is caught before rebuild time.

This is a refactor proposal, not a functional migration. Every phase should preserve the current host outputs unless an intentionally separate behavior change is reviewed.

## 2. Current structure

The tracked repository currently contains:

- 218 tracked files.
- 158 tracked Nix module files.
- One flake entry point using `flake-parts` and `import-tree`.
- A `modules/` tree where most files are flake-parts modules that register one or more deferred NixOS or Home Manager modules.
- Host definitions under `modules/hosts/`.
- Role profiles under `modules/profiles/`.
- Non-Nix desktop assets under `config/`.
- Operational docs and proposals under `docs/`.
- SOPS secrets under `secrets/`.

The current pattern is:

```nix
{ config, ... }:
let
  m = config.flake.modules;
in {
  flake.modules.nixos.some-name = { ... }: {
    imports = [
      m.nixos.other-name
    ];
  };
}
```

Hosts then set `configurations.nixos.<host>.module` and import the profiles and host-specific modules they need.

That pattern is good. It gives automatic discovery without hidden imports, and it keeps composition local to the host.

## 3. What is working well

### Dendritic registration

Each small file contributes a leaf to the module graph. This keeps the module registry discoverable and avoids category-level `default.nix` boilerplate.

### Explicit host composition

Hosts import `profile-base`, `profile-desktop` or `profile-server`, then add hardware, networking, host services, and Home Manager extras. A reader can inspect one host and see its composition without chasing a long stack of aggregators.

### Role profiles

The base, desktop, and server profiles are the right abstraction level. They avoid repeating common imports while leaving host-specific services visible.

### Config assets are separate

QML, scripts, keyboard layouts, wallpapers, and theme material live under `config/` rather than being embedded in Nix strings everywhere.

### Docs have an established place

Operational references and proposals already have an index. This proposal should follow that convention rather than invent a new planning system.

## 4. Main structural problems

### 4.1 The dendritic contract is implicit

`README.md` says the repo follows the dendritic pattern, but there is no short local contract that says what a module file is allowed to do, how to name registrations, when a file may register multiple modules, and where host-specific logic belongs.

Result: new modules can drift into personal style, especially because this repo mixes NixOS modules, Home Manager modules, flake-parts modules, hosts, generated hardware files, and local service orchestration.

### 4.2 Flake control-plane files share a directory with leaves

`configurations`, `formatter`, `dev-shell`, `systems`, and `meta` are not the same kind of thing as `desktop.hyprland`, `services.klipper-host`, or `hosts.kepler.k3s-cluster`.

They are currently all imported from `modules/`. This works, but it weakens the mental model:

- Some files define top-level flake behavior.
- Some files only register NixOS leaves.
- Some files only register Home Manager leaves.
- Some files register both.
- Host files define actual `nixosConfigurations`.

The architecture is easier to maintain if the control plane is visually distinct, even if `import-tree` still scans the whole `modules/` tree.

### 4.3 Naming is mostly consistent, but not governed

The registry names are generally readable: `profile-base`, `kepler-k3s-cluster`, `home-manager-base`, `packages-shared`, `dev-python`.

The issue is that there is no rule for:

- Prefixing host-specific modules.
- Prefixing Home Manager versus NixOS modules.
- Naming private helper modules such as `_k3s-node`.
- Deciding when a module name should be service-first versus host-first.
- Avoiding future collisions between common service modules and host service modules.

### 4.4 Some modules have become domains, not leaves

A few files are large enough that they now represent whole domains:

- Desktop shell/window manager configuration.
- Obsidian configuration.
- Kepler k3s MicroVM cluster.
- Klipper host.
- Starship shell prompt.
- Easyeffects/audio routing.

Large modules are not automatically bad. The problem is that they hide multiple decision boundaries in one file: options, packages, services, generated config, activation behavior, and external operational assumptions.

### 4.5 Host files mix composition with policy

Several host `default.nix` files do more than compose imports. They also set kernel policy, bootloader details, zram, auto-upgrade policy, CPU microcode, service toggles, and Home Manager wiring.

That is fine for small hosts, but it scales poorly as a host becomes a platform. Kepler and discovery already read more like product surfaces than simple machines.

### 4.6 Generated hardware files are tracked beside authored files

The `_hw-generated.nix` convention is clear, but generated files live directly beside authored host modules. This makes it easier to edit generated material by accident and harder to scan host intent.

### 4.7 Ignored local-state directories clutter the workspace

The Git tree is clean, but the working directory contains ignored or local material such as agent state, generated workflow output, runtime data, logs, local repo references, and downloaded vendor artifacts.

That material is not a Git problem because `.gitignore` covers it. It is still a repo ergonomics problem: `find`, editor file search, and mental scanning all have to filter local-state noise.

### 4.8 The old dendritic design doc is now partly historical

The old design says the current layout follows the design, but the implementation has evolved. In particular, the current repo did not settle on a dedicated `modules/flake/` plus `modules/nixos/` split. Instead, it uses broad `import-tree` discovery and deferred module registration throughout `modules/`.

That is a valid design, but the docs should call the older document historical where it no longer matches the implementation.

## 5. Design principles

Use these as the review bar for any structural change.

### Preserve dendritic discovery

Do not replace the current graph with broad category aggregators. A new file should be discoverable by being imported automatically and by registering a named leaf.

### Keep composition explicit

Profiles and hosts should import named leaves. Avoid hidden imports that make a host gain behavior just because a file exists in a directory.

### Separate registration from behavior where it helps

Tiny modules can register inline. Larger domains should have a registration file plus implementation files, or a directory with named pieces. The registry remains small; the behavior gets readable boundaries.

### Host-specific code starts with the host name

If a module only applies to one host, its registry name should start with that host. If it can apply to multiple hosts, it should live outside the host subtree and use a service or capability name.

### Generated material should look generated

Generated or captured hardware state should be visually separated from authored policy. A reader should not have to infer which files are safe to edit.

### Verification gates should be cheap and local first

The repo already has expensive dry-build checks. Add lightweight structural checks that run before host builds and catch naming, registration, and generated-file mistakes.

## 6. Proposed target structure

This is the proposed shape, not an all-at-once file move.

```text
modules/
  _flake/
    configurations.nix
    dev-shell.nix
    formatter.nix
    meta.nix
    systems.nix

  profiles/
    base.nix
    desktop.nix
    server.nix

  common/
    nix.nix
    user.nix
    home-manager-base.nix
    overlays.nix
    secrets.nix

  nixos/
    boot/
    networking/
    security/
    services/
    hardware/
    virtualization/
    server/

  home/
    shell/
    terminal/
    desktop/
    browser/
    dev/
    packages/

  domains/
    k3s-microvm/
    klipper/
    obsidian/
    quickshell/

  hosts/
    kepler/
      default.nix
      hardware/
      networking.nix
      roles/
      services/
      home.nix
    discovery/
    orion/
    pathfinder/
    laptop/
    archinaut/
```

The key point is not these exact names. The key point is the separation of concerns:

- `_flake/` contains flake-parts control-plane modules.
- `nixos/` contains reusable NixOS leaves.
- `home/` contains reusable Home Manager leaves.
- `domains/` contains large multi-file features with their own internal structure.
- `hosts/` contains host assembly and host-only policy.
- `profiles/` remains the small role composition layer.

If a full move to `nixos/` and `home/` feels too disruptive, keep the current top-level directories and only add `_flake/`, `domains/`, and host anatomy cleanup. That captures most of the benefit with less churn.

## 7. Recommended phases

### Phase 0 - Document and lint the current contract — ✅ done (2026-06-27)

Add a short architecture note that defines the local dendritic contract:

- Every imported `.nix` file under `modules/` must be a flake-parts module.
- Reusable NixOS leaves register under `flake.modules.nixos`.
- Reusable Home Manager leaves register under `flake.modules.home`.
- Hosts register `configurations.nixos.<host>.module`.
- Profiles are composition modules only.
- Host-only leaves use `<host>-<capability>`.
- Reusable leaves use `<domain>-<capability>` or `<capability>`.
- Private helpers are not registered and may start with `_`.

Add a cheap `just structure-check` recipe that verifies:

- Registered module names are unique.
- Host-specific registry names match a known host prefix.
- Private helper files are not registered.
- Generated hardware files contain a generated-file header.
- Large files over an agreed threshold are reported, not failed initially.

This phase has almost no behavior risk and gives future changes a review target.

### Phase 1 - Move flake control-plane modules under `_flake/`

Move only the flake control-plane modules:

- Configurations.
- Dev shell.
- Formatter.
- Meta options.
- Supported systems.

Keep `flake.nix` importing `./modules` unless there is a strong reason to change it. The goal is visual separation, not a semantic rewrite.

Expected result:

- New readers can tell which files shape flake outputs.
- Reusable NixOS and Home Manager leaves stop being visually mixed with flake control code.
- The existing dendritic registry remains intact.

Verification:

- `nix flake check`.
- `just fmt-check`.
- At least one dry-build for a desktop host and one server host.

### Phase 2 - Normalize top-level reusable leaves

Move root-level reusable leaves into clearer homes:

- User, common Nix settings, overlays, secrets, and Home Manager wiring into `common/`.
- Shell and terminal Home Manager modules under `home/`.
- Browser, desktop, dev, package Home Manager modules under `home/`.
- NixOS system modules under `nixos/`.

This phase should be mechanical. Registry names should stay stable unless there is a collision or misleading name.

Verification:

- `just fmt-check`.
- `nix flake check`.
- `just dry-all` before and after, comparing changed host closures when practical.

### Phase 3 - Give large domains directories

Split large feature modules only where the split exposes real boundaries.

Recommended first candidates:

- `domains/k3s-microvm/`
- `domains/obsidian/`
- `domains/klipper/`
- `domains/quickshell/`
- `domains/audio-routing/`

Good internal boundaries:

- Options.
- Packages.
- System services.
- Generated text/config.
- Activation scripts.
- Firewall/network exposure.
- Operational assumptions.

Avoid splitting a file just because it is long. A split is useful when a future edit can happen in one smaller area without reading unrelated behavior.

Verification:

- One domain at a time.
- Dry-build every host that imports that domain.
- For service domains, run or document the service-specific post-deploy health check.

### Phase 4 - Standardize host anatomy

Adopt a consistent host directory shape:

```text
hosts/<host>/
  default.nix
  hardware/
    generated.nix
    policy.nix
  networking.nix
  home.nix
  services/
    <service>.nix
```

Guidelines:

- `default.nix` composes imports and sets only top-level host identity.
- Hardware capture and hardware policy are separate.
- Home Manager host additions live in `home.nix`.
- Host-only services live under `services/`.
- Reusable services move out of the host tree.

Do this host by host. Start with the least complex host to prove the shape, then apply it to platform hosts.

Suggested order:

1. Pathfinder or laptop.
2. Orion.
3. Discovery.
4. Kepler.
5. Archinaut.

### Phase 5 - Move ignored local state out of the repo view

Keep `.gitignore`, but reduce workspace noise:

- Put agent/runtime state under a single ignored `.local/` or `.work/` directory when tools allow it.
- Keep sister-repo symlinks under `references/repos/`.
- Keep downloaded vendor artifacts out of the repo root.
- Keep logs and generated databases out of root-level scans.

This is mostly developer ergonomics, but it matters because the repo is already large enough that search noise slows maintenance.

### Phase 6 - Refresh docs

Update the docs to distinguish:

- Historical dendritic migration design.
- Current dendritic contract.
- Current host inventory.
- Current operational recipes.
- Active proposals.

The old dendritic design can remain, but it should be labeled historical where it no longer matches the implemented layout.

## 8. Naming policy

Adopt these rules for future modules.

### Registry names

Use lowercase kebab-case.

```text
flake.modules.nixos.<name>
flake.modules.home.<name>
configurations.nixos.<host>.module
```

### Reusable modules

Use service or capability names:

```text
nixos.openssh
nixos.firewall
nixos.distributed-builds
home.fish
home.vscode
```

### Host-only modules

Prefix with host name:

```text
nixos.kepler-k3s-cluster
nixos.discovery-haos
home.pathfinder-ssh
```

### Profiles

Use `profile-<role>`:

```text
nixos.profile-base
nixos.profile-desktop
nixos.profile-server
home.profile-base
home.profile-desktop
```

### Helpers

Use `_` prefix for helpers that are imported manually and not registered:

```text
_k3s-node.nix
```

If a helper grows options or is imported by multiple domains, promote it to a named reusable module.

## 9. Host anatomy policy

Each host should answer five questions quickly:

1. What role does this host play?
2. Which profiles does it import?
3. Which hardware policy is authored versus generated?
4. Which network identity and exposed ports belong to it?
5. Which host-only services make it special?

The host `default.nix` should be the table of contents for those answers. It should not become the full implementation of all five.

## 10. Large-module policy

Use this decision rule before splitting:

- Split when a module contains multiple independently reviewable surfaces.
- Split when generated config text dominates the file.
- Split when options and implementation are far apart.
- Split when a service has its own operational lifecycle.
- Do not split tiny modules just to satisfy a directory taxonomy.

Recommended soft thresholds:

- Over 200 lines: review whether the file is still one concept.
- Over 400 lines: require a note explaining why it remains one file.
- Over 600 lines: strongly prefer a domain directory.

These thresholds should report in `structure-check` first. Do not fail the build until the policy has been applied to obvious cases.

## 11. Verification policy

Every structural phase should run:

```bash
just fmt-check
nix flake check
```

Phases that move NixOS modules should also run:

```bash
just dry-all
```

When full fleet dry-build is too slow, use a smaller gate during iteration:

```bash
just dry pathfinder
just dry kepler
```

Then run `just dry-all` before merging.

Behavior-sensitive domains need additional checks:

- K3s: verify MicroVM services and cluster nodes.
- Desktop shell: verify Hyprland session, Quickshell, portals, and Home Manager activation.
- Storage: verify mounts and backup/snapshot timers.
- Secrets: verify SOPS age key availability and activation cleanup.
- Remote hosts: verify SSH on port 2222 after switch.

## 12. Risks and mitigations

### Risk: file moves break imports

Mitigation: keep registry names stable during mechanical moves. Move files first, rename modules later only when necessary.

### Risk: a structural cleanup changes host behavior

Mitigation: one host or one domain per PR. Dry-build before and after. Avoid option changes in the same commit as file moves.

### Risk: too much taxonomy makes the repo harder to navigate

Mitigation: only add directories where they encode a real boundary. Do not create empty category folders.

### Risk: docs drift again

Mitigation: keep the architecture contract short and link it from the README and docs index. Treat old design docs as historical references.

### Risk: `import-tree` starts importing files that are not flake-parts modules

Mitigation: keep helpers either outside the scanned tree or named and shaped so they are not picked up by `import-tree`. If helpers must live under `modules/`, confirm the current import-tree behavior for underscore-prefixed files and enforce that in `structure-check`.

## 13. Acceptance criteria

The repo structure improvement is complete when:

- A current dendritic architecture note exists and is linked from the docs index.
- Flake control-plane files are visually separate from reusable leaves.
- Host-only module names consistently use host prefixes.
- At least the largest multi-surface modules have been split or intentionally documented as exceptions.
- Host directories follow one recognizable anatomy.
- Ignored local-state material is no longer visually mixed with source material in normal workspace scans.
- `structure-check`, formatting, flake checks, and host dry-builds pass.

## 14. Recommended next action

Start with Phase 0 and Phase 1 only:

1. Write the short dendritic architecture contract.
2. Add `just structure-check` in report-only mode.
3. Move flake control-plane modules into `_flake/`.
4. Run `nix flake check`.
5. Run one desktop dry-build and one server dry-build.

This gives the repo a stronger backbone before any larger file moves. It also creates a safety rail for the later phases.
