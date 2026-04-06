# mynixos -- Product Overview

## Product Vision

mynixos is a typed functional DSL for NixOS configuration. It provides a `my.*` namespace that turns system configuration into a composable, type-safe API. Instead of writing raw NixOS modules, users declare intent through structured options -- and mynixos handles the implementation.

The core proposition: **defaults that work, `mkDefault` so you always win.** Every opinionated choice can be overridden. User configuration lives separately (in `/etc/nixos/`); mynixos provides only types, options, and implementations.

A single `mkSystem` call assembles hardware, users, filesystems, secrets, and themes into a complete NixOS system.

## Domain Model

The `my.*` namespace is organized into four tiers:

### Core Domains

- **`my.system`** -- Hostname, kernel, architecture, persistence aggregation. The foundation every system needs.
- **`my.users`** -- Per-user configuration with feature bundles, apps, environment, secrets, mounts, and YubiKeys. Users are only created in NixOS when `fullName` is defined.
- **`my.hardware`** -- Hardware detection and driver modules: CPU (AMD/Intel), GPU (AMD/NVIDIA), bluetooth, boot (UEFI/dual-boot/secure boot), cooling (NZXT Kraken), memory optimization, storage (NVMe/SATA/SSD/USB), USB (xHCI/Thunderbolt/HID), peripherals (Elgato Stream Deck). Includes complete motherboard and laptop profiles.
- **`my.security`** -- Security stack: secure boot (lanzaboote), YubiKey support, audit rules.

### Feature Domains

- **`my.graphical`** -- Desktop environment (Hyprland + display manager). Auto-enabled when any user sets `graphical.enable = true`.
- **`my.dev`** -- Development infrastructure (Docker rootless, binfmt, AppImage). Auto-enabled from user flags.
- **`my.ai`** -- AI infrastructure (Ollama with ROCm/AMD GPU support). System-level service auto-derived from user `ai.enable`.
- **`my.streaming`** -- OBS Studio, virtual camera, polkit rules. Auto-derived from user `graphical.streaming.enable`.
- **`my.video`** -- Virtual video devices (v4l2loopback). Auto-enabled by streaming.
- **`my.audio`** -- Audio subsystem configuration.
- **`my.performance`** -- Kernel tunables, zram compressed swap, vmtouch RAM caching.

### Infrastructure Domains

- **`my.infra`** -- Infrastructure services: k3s Kubernetes cluster, GitHub Actions Runner Controller (ARC) with optional GPU passthrough.
- **`my.storage`** -- Impermanence (tmpfs root + persistent storage). Configures persist paths, ccache, flake repo cloning, and user data persistence.
- **`my.secrets`** -- sops-nix integration for secrets management (age keys, SSH keys, GnuPG/YubiKey decryption).

### Cross-Cutting Concerns

- **`my.theming`** -- Theming system with vogix (runtime theme management, default) and stylix (static theming, legacy). Per-user theme scheme/variant selection.
- **`my.environment`** -- Environment variables, XDG portals, locale, timezone, display manager (greetd/GDM/SDDM/LightDM), MOTD, default editor and browser.
- **`my.presets`** -- Preset configurations (workstation preset with opinionated app defaults).
- **`my.filesystem`** -- Filesystem type (`"disko"` for declarative partitioning, `"nixos"` for standard) and config path.

## Architecture

### Three-File Module Pattern

Every module follows a consistent structure:

```
my/category/item/
  options.nix    -- Type definitions (mkOption, mkEnableOption, submodules)
  default.nix    -- Implementation (mkIf, mkMerge for conditional config)
  mynixos.nix    -- Opinionated defaults (mkDefault values, optional)
```

Options define the contract. Implementations map those options to NixOS/home-manager config. Opinionated defaults (mynixos.nix) wire up sensible choices that users can override.

### System Assembly (mkSystem)

`mkSystem` is the entry point. It accepts:

| Parameter      | Purpose                                          |
|---------------|--------------------------------------------------|
| `hostname`    | System hostname                                  |
| `hardware`    | List of hardware module paths                    |
| `users`       | List of user definitions (nixosUser + homeManager)|
| `my`          | Direct `my.*` configuration attrset              |
| `config`      | Additional NixOS config path                     |
| `extraModules`| Additional NixOS modules                         |

Assembly order:
1. Hardware modules
2. The mynixos module (`self.nixosModules.default`)
3. Filesystem modules (disko or nixos, based on `my.filesystem.type`)
4. NixOS user definitions + home-manager configuration
5. sops-nix for secrets management
6. Theme modules
7. Direct `my.*` config and extra modules

### Option Flow

```
options.nix  -->  flake.nix (mkOptionsModule)  -->  my.* namespace available
                                                         |
default.nix  -->  flake.nix (imports list)     -->  reads config.my.*, produces NixOS config
                                                         |
mynixos.nix  -->  flake.nix (options list)     -->  injects mkDefault values into user submodules
```

### App Configuration Model

Apps are per-user, structured as `my.users.<name>.apps.<feature>.<category>.<app>`. Each app has a uniform interface created by `mkAppOption`:

- `.enable` -- Whether the app is active
- `.persisted` -- Whether to persist app data (default: true)
- `.persistedDirectories` -- Directories to persist (relative to home)
- `.persistedFiles` -- Files to persist (relative to home)
- App-specific extra options (e.g., Hyprland sensitivity, bash history size)

The `appHelpers.shouldEnable` function dynamically searches all feature namespaces to determine if an app is enabled, enabling cross-feature app lookup.

### Feature Bundle Auto-Derivation

System-level features auto-derive from user flags:

```
user.graphical.enable = true  -->  my.graphical.enable = true (system)
user.dev.enable = true        -->  my.dev.enable = true (system)
user.ai.enable = true         -->  my.ai.enable = true (system)
user.graphical.streaming      -->  my.streaming.enable + my.video.virtual.enable
```

### Persistence Aggregation

Apps declare their persistence paths. The aggregation pipeline collects these:

```
app.persistedDirectories  -->  aggregation.nix  -->  my.system.persistence.aggregated
feature persistence       -->  feature-aggregation.nix  -->  my.system.persistence.features
both                      -->  impermanence.nix  -->  environment.persistence (nix-community/impermanence)
```

## Current State

### Quantitative Overview

| Metric                    | Count |
|--------------------------|-------|
| Total Nix files under my/ | 147   |
| Implementation modules    | 101   |
| Options definitions       | 21    |
| Opinionated defaults      | 5     |
| App modules               | 49    |
| App categories            | 28    |
| Feature bundles            | 4 (terminal, graphical, dev, ai) |
| Hardware driver areas      | 10 (cpu, gpu, bluetooth, boot, cooling, memory, storage, usb, peripherals, motherboards/laptops) |
| Hardware profiles          | 2 motherboards + 1 laptop + 1 cooler |
| Webapps                   | 17    |
| Infrastructure services   | 2 (k3s, GitHub runner) |
| Security key types        | 3 (YubiKey, SoloKey, NitroKey) |
| Display managers supported| 4 (greetd, GDM, SDDM, LightDM) |
| Supported architectures   | 2 (x86_64-linux, aarch64-linux) |

### CI/CD Pipeline

Single workflow (`ci-and-release.yml`) on every PR and push to master:

1. **Nix Flake Check** -- `nix flake check --print-build-logs` (includes treefmt formatting)
2. **Nix Lint** -- `statix check .` + `deadnix --fail .`
3. **Release Please** -- Automated versioning and changelog on master (runs after CI passes)

Pre-commit hooks (via git-hooks.nix): treefmt, statix, deadnix.

### Release Management

- **release-please** with manifest-based config
- Conventional commits drive versioning (feat = minor, fix = patch)
- Current version: 0.1.2
- Changelog sections: Features, Bug Fixes, Code Refactoring, Documentation, Miscellaneous

### External Dependencies

| Dependency       | Purpose                        | Source                               |
|-----------------|--------------------------------|--------------------------------------|
| nixpkgs          | Package set                    | nixos-unstable                       |
| home-manager     | User environment               | Custom fork (webapps-module)         |
| disko            | Declarative disk partitioning  | nix-community/disko                  |
| impermanence     | Tmpfs root + persistent storage| nix-community/impermanence           |
| lanzaboote       | Secure boot                    | nix-community/lanzaboote             |
| sops-nix         | Secrets management             | Mic92/sops-nix                       |
| stylix           | Static theming (legacy)        | danth/stylix                         |
| vogix            | Runtime theme management       | i-am-logger/vogix                    |
| nixos-hardware   | Hardware quirks                | Custom fork (i-am-logger)            |
| treefmt-nix      | Formatter orchestration        | numtide/treefmt-nix                  |
| git-hooks        | Pre-commit hooks               | cachix/git-hooks.nix                 |

## Quality Metrics

### Type Safety

- **Typed:** All `my.*` options use `mkOption` with explicit types (enum, submodule, bool, int, str, package, path, listOf, attrsOf, constrained floats). Hardware CPU/GPU use enum types (`"amd" | "intel" | "nvidia"`). Filesystem type is enum (`"disko" | "nixos"`).
- **Structured:** Apps use `mkAppOption` for uniform interface generation with typed extra options.
- **Gaps:** Some options use `lib.types.attrsOf lib.types.anything` for passthrough (Hyprland settings), bypassing type checking. Webapp options use bare `lib.types.bool` without `mkAppOption` structure.

### Test Coverage

- **Module evaluation:** `nix flake check` validates that all modules evaluate without errors and that the flake structure is correct.
- **No unit tests:** No NixOS test VMs, no option validation tests, no integration tests exist.
- **Static analysis:** statix (anti-pattern detection) and deadnix (dead code detection) run on every PR.

### Code Quality

- Formatting enforced via treefmt (nixpkgs-fmt + shellcheck + shfmt).
- All modules explicitly imported in flake.nix (no dynamic discovery).
- Some known duplication between hardware profile options and driver modules.

## Roadmap

Development priorities are tracked as GitHub issues:

### P0: Testing Foundation

- **#38** -- Module evaluation tests
- **#39** -- Type validation tests
- **#40** -- Integration/NixOS VM tests
- **#53** -- CI test infrastructure

### P1: Dead Code and Deduplication

- **#41 through #46** -- Remove dead code, deduplicate hardware options, consolidate shared patterns across modules

### P2: Type Safety

- **#47 through #49** -- Replace `anything` types with proper submodules, add type constraints to webapp options, strengthen option validation

### P3: Architecture

- **#50 through #52** -- Module dependency graph improvements, option namespace consistency, library function consolidation

### Documentation

- **#54** -- API reference documentation

## Design Principles

### Opinionated Defaults with User Override

Every opinionated choice uses `mkDefault`, which has lower priority than direct user assignment. Users always win:

```nix
# mynixos sets:
browsers.brave.enable = lib.mkDefault true;
# User overrides (takes priority):
browsers.brave.enable = false;
```

### Per-User App Configuration

Apps are scoped per-user, not per-system. Two users on the same machine can have different app sets, different shells, different editors.

### Feature Bundles

Four feature bundles (`terminal`, `graphical`, `dev`, `ai`) activate curated sets of apps. Each bundle's mynixos.nix file defines which apps are enabled by default when the bundle is active. Individual apps can still be toggled independently.

### System-Level Auto-Derivation

System services are never configured directly by users. When any user enables a feature (e.g., `graphical.enable = true`), mynixos automatically enables the corresponding system-level service (Hyprland, display manager, Docker, Ollama).

### Persistence Aggregation

Apps declare what they need persisted. The aggregation pipeline collects these declarations across all users and all apps, then configures impermanence in one place. This eliminates manual persistence management.

### Three-File Module Pattern

Separation of concerns at the file level: types are separate from implementation, and both are separate from opinionated defaults. This makes it possible to use mynixos types without mynixos opinions.
