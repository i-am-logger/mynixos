# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

mynixos is a typed functional DSL for NixOS configuration providing type-safe, composable APIs for system configuration. It uses a `my.*` namespace to expose strongly-typed options that replace imperative NixOS modules with functional composition. User configs live separately in `/etc/nixos/Systems/`; mynixos provides only types, options, and implementations.

## Build Commands

```bash
nix flake check          # Evaluate flake and check syntax
nix fmt                  # Format all Nix files (uses nixpkgs-fmt)
nix flake show           # Check flake outputs
```

CI runs `nix flake check` (which includes treefmt formatting via `checks.formatting`), `statix check .`, and `deadnix --fail .` on every PR.

## Core Architecture

### The `my/` Module Structure

All modules live under `my/category/item/` using a three-file pattern:

```
my/category/item/
├── options.nix    # Type definitions (mkOption, mkEnableOption, submodules)
├── default.nix    # Implementation (mkIf, mkMerge for conditional config)
└── mynixos.nix    # Opinionated defaults (mkDefault values, optional)
```

Options are imported in flake.nix's options section. Implementations are imported in flake.nix's imports list. The `modules/` directory is legacy and only holds custom home-manager modules not yet upstreamed.

### `my.*` Namespace

- **`my.system`** - Core system config (hostname, kernel, scripts)
- **`my.users`** - User configs with apps, features (graphical, dev, terminal, ai), environment, defaults
- **`my.hardware`** - Hardware detection (cpu, gpu, bluetooth, boot, cooling, memory, peripherals, storage, usb)
- **`my.security`** - Security features (yubikey)
- **`my.graphical`** - Desktop environment (hyprland)
- **`my.dev`** - Development tools
- **`my.ai`** - AI tools (Ollama with ROCm)
- **`my.themes`** - Theming (vogix by default, hypr-vogix screen overlay, stylix legacy/disabled)
- **`my.network`** - Network defense (addrwatch, pcap, tshark, suricata, zeek, p0f, AIDE, netflow/ntopng, blocky DNS)
- **`my.infra`** - Infrastructure services (github-runner, k3s)
- **`my.storage`** - Impermanence (tmpfs root + persistent storage)
- **`my.environment`** - Environment variables and paths
- **`my.performance`** - Performance tuning
- **`my.streaming`** - Streaming setup
- **`my.video`** - Virtual video devices
- **`my.presets`** - Preset configurations
- **`my.filesystem`** - Filesystem type (`"disko"` or `"nixos"`) and config path

### System Assembly (`lib/mkSystem.nix`)

`mkSystem` takes: `hostname`, `hardware` (list of module paths), `users` (list with nixosUser and homeManager), `config`, `extraModules`, `my` (direct mynixos config). It assembles:
1. Hardware modules
2. The mynixos module itself (`self.nixosModules.default`)
3. Filesystem modules (disko or nixos based on `my.filesystem.type`)
4. User definitions mapped to NixOS users + home-manager configs
5. sops-nix, theme modules (vogix by default), extra modules

### Key Library Functions (`lib/`)

- **`mkSystem`** - Main system builder (see above)
- **`activeUsers`** - Filters users to only those with `fullName` defined (fully configured users)
- **`mkAppOption`** (`lib/app-options.nix`) - Creates structured app options with enable, persisted, persistedDirectories, persistedFiles
- **`floatBetween`** (`lib/app-options.nix`) - Float type constrained to a range [min, max]

### Key Design Patterns

**App Configuration:** Apps are per-user under `config.my.users.<name>.apps.<feature>.<category>.<app>`. Each app has `.enable`, `.persisted`, `.persistedDirectories`, `.persistedFiles`. Implementations map over `config.my.users` and use `home-manager.users = mapAttrs`.

**Persistence Aggregation:** Apps contribute persistence paths to `my.system.persistence.aggregated`, features to `my.system.persistence.features`. Aggregation modules: `my/storage/impermanence/{aggregation.nix, feature-aggregation.nix, impermanence.nix}`.

**User Management:** Users are only created in NixOS if `fullName` is defined. Users without `fullName` can still have mounts, yubikeys, and email. Each user can enable feature bundles (graphical, dev, terminal, ai) and configure 50+ individual apps.

**Hardware Profiles:** Exported via `mynixos.lib.hardware.*` for external use. Profiles in `my/hardware/{motherboards,laptops}/` include a `default.nix` importing all driver modules.

## Adding a New App Module

1. Create `my/users/apps/<category>/<app-name>/` with `options.nix`, `default.nix`, and optionally `mynixos.nix`
2. Import the implementation module in flake.nix's imports list
3. Add the option in the appropriate section of flake.nix's options
4. Use `mkIf` to conditionally enable based on the user's app setting

## Adding a New Feature

1. Create `my/<feature-name>/` with `options.nix` and `default.nix`
2. Add option import to flake.nix's options section
3. Import the implementation in flake.nix's imports list
4. Implement feature logic using `mkIf config.my.<feature-name>.*`

## Important Constraints

### Single Commit Convention

When working on a feature branch, maintain a single commit. Use `git commit --amend` to update the commit rather than creating new ones.

### No Generated Signatures

Do NOT add "Generated with Claude Code" or similar text to files, commits, PRs, or comments.

### Opinionated Defaults Pattern

Use `mkDefault` for opinionated defaults that users can override:
```nix
my.apps.browsers.brave = mkDefault true;  # Enabled by default but overridable
```

Regular boolean options without defaults:
```nix
my.apps.browsers.firefox = mkEnableOption "Firefox browser";  # Disabled by default
```

## Code Style

- Use `with lib;` at the top of module files
- Prefer `mkIf` over explicit conditionals
- Use `mkMerge` when conditionally merging multiple attribute sets
- Use `cfg` for `config.my.<namespace>`
- Keep implementations in `my/` files, not in flake.nix's config section
- All modules explicitly imported in flake.nix (no dynamic discovery)

## External Dependencies

- `nixpkgs` (nixos-unstable), `disko`, `impermanence`
- `home-manager` (custom fork: i-am-logger/home-manager#feature/webapps-module)
- `stylix`, `vogix`, `lanzaboote`, `sops-nix`
- `nixos-hardware` (custom fork: i-am-logger/nixos-hardware)
