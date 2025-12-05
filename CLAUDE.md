# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

mynixos is a typed functional DSL for NixOS configuration providing type-safe, composable APIs for system configuration. It uses a `my.*` namespace to expose strongly-typed options that replace imperative NixOS modules with functional composition.

## Core Architecture

### The `my.*` Namespace Structure

The entire configuration surface is organized into typed namespaces:

- **`my.features`** - High-level feature bundles (security, graphical, github-runner, ai, webapps, streaming, development, system, performance, audio, impermanence, motd)
- **`my.users`** - User configurations with packages, passkeys, shells, editors, mounts, yubikeys
- **`my.hardware`** - Hardware detection and configuration (cpu, gpu, bluetooth, audio)
- **`my.apps`** - Individual application configurations organized by category (browsers, terminals, editors, shells, fileManagers, multiplexers, etc.)
- **`my.presets`** - Preset configurations that enable opinionated app stacks (workstation)
- **`my.infra`** - Infrastructure services (k3s)
- **`my.storage`** - Storage configuration (impermanence with tmpfs root + persistent storage)
- **`my.boot`** - Boot configuration (uefi, secure boot, dual-boot)
- **`my.filesystem`** - Filesystem configuration type and path (disko or nixos)
- **`my.themes`** - Theming system configuration (stylix)

### Key Design Principles

1. **Type Safety First** - All options are strongly typed; invalid configurations are caught at evaluation time
2. **Functional Composition** - Features compose cleanly through the type system
3. **Opinionated Defaults** - Sensible defaults marked with `mkDefault` (e.g., `my.apps.browsers.brave = mkDefault true`)
4. **Separation of Types and Data** - mynixos provides types/options/implementations; user configs in `/etc/nixos/Systems/` provide the data

### Module Organization

- **`modules/features/`** - Feature implementations that read from `my.features.*` (users.nix, security.nix, graphical.nix, hyprland.nix, themes.nix, github-runner.nix, ai.nix, webapps.nix, streaming.nix, development.nix, system.nix, audio.nix, performance.nix, impermanence.nix, motd.nix)
- **`modules/apps/`** - Individual app modules organized by category (browsers/, terminals/, editors/, shells/, etc.)
- **`modules/presets/`** - Preset configurations (workstation.nix)
- **`modules/hardware/`** - Hardware-specific modules (cpu/, gpu/, bluetooth/, boot/, motherboards/, laptops/)
- **`modules/security/`** - Security modules (yubikey.nix)
- **`modules/infra/`** - Infrastructure services (services/k3s.nix)
- **`lib/`** - Core library functions (mkSystem.nix, mkInstallerISO.nix)
- **`images/`** - Installer ISO and container image builders

### Critical Implementation Details

#### User Management (modules/features/users.nix)

- Users are only created in NixOS if `fullName` is defined
- Users without `fullName` can still have mounts, yubikeys, and email configured (they come from external user definitions)
- All user mounts are processed regardless of whether the user is created by mynixos

#### Hardware Configuration Flow

1. Hardware modules are passed to `mkSystem` via the `hardware` parameter (list of paths)
2. CPU/GPU auto-detection triggers appropriate driver modules
3. Motherboard/laptop configs live in `modules/hardware/{motherboards,laptops}/` and are exported via `mynixos.hardware.*`

#### Filesystem Configuration

- `my.filesystem.type` can be `"disko"` (declarative partitioning) or `"nixos"` (standard NixOS)
- `my.filesystem.config` points to the configuration file path
- `mkSystem` automatically imports the appropriate modules based on type

#### Theme System

- `my.themes.type` currently only supports `"stylix"`
- `my.themes.config` points to a stylix configuration module
- Opinionated defaults for fonts, opacity, cursor theme, etc.

## Common Development Tasks

### Building the Flake

```bash
# Check flake outputs
nix flake show

# Check flake evaluation
nix flake check

# Format Nix code
nix fmt
```

### Testing Changes

When modifying mynixos modules:

1. Changes to `my.*` options in flake.nix require careful consideration of downstream impacts
2. Test with a real system config in `/etc/nixos/Systems/`
3. Verify type safety by intentionally passing invalid values

### Adding a New App Module

1. Create `modules/apps/<category>/<app-name>.nix`
2. Add option to `my.apps.<category>.<app-name>` in flake.nix (lines 633-833)
3. Import the module in flake.nix's imports list (lines 120-166)
4. Implement using `mkIf` to conditionally enable based on `my.apps.<category>.<app-name>`

### Adding a New Feature

1. Create `modules/features/<feature-name>.nix`
2. Add option to `my.features.<feature-name>` in flake.nix (lines 190-457)
3. Import the module in flake.nix's imports list (lines 100-114)
4. Implement feature logic based on `config.my.features.<feature-name>`

### Working with Hardware Profiles

Hardware profiles in `modules/hardware/{motherboards,laptops}/` should:
- Include a `default.nix` that imports all driver modules
- Separate concerns into individual driver files (network.nix, bluetooth.nix, gpu.nix, etc.)
- Be exportable via `mynixos.hardware.*` in flake.nix (lines 74-85)
- Be generic enough for anyone with that hardware to use

### Image Building and Testing

GitHub runner image testing (see images/TESTING.md):

```bash
# Run comprehensive tests (20 test suites)
nix build /etc/nixos#checks.x86_64-linux.github-runner-test

# Build runner image
nix build /etc/nixos#github-runner-image

# Load and test manually
docker load < result
docker run --rm -it github-runner:nixos-latest bash
```

## Important Constraints

### Single Commit Convention

When working on a feature branch, maintain a single commit. Use `git commit --amend` to update the commit rather than creating new ones.

### No Generated Signatures

Do NOT add "Generated with Claude Code" or similar text to:
- Files in the repository
- Git commit messages
- Pull request descriptions
- Code comments

### Opinionated Defaults Pattern

Use `mkDefault` for opinionated defaults that users can override:

```nix
my.apps.browsers.brave = mkDefault true;  # Enabled by default but overridable
```

Regular boolean options without defaults:

```nix
my.apps.browsers.firefox = mkEnableOption "Firefox browser";  # Disabled by default
```

### External Dependencies

This flake depends on:
- `nixpkgs` (nixos-unstable)
- `disko` - Declarative disk partitioning
- `impermanence` - Tmpfs root with persistent storage
- `home-manager` (custom fork: i-am-logger/home-manager#feature/webapps-module)
- `stylix` - Theming system
- `lanzaboote` - Secure boot
- `nixos-hardware` (custom fork: i-am-logger/nixos-hardware)
- `sops-nix` - Secrets management

## Code Style

- Use `with lib;` at the top of module files for common lib functions
- Prefer `mkIf` over explicit conditionals
- Use `mkMerge` when conditionally merging multiple attribute sets
- Type all options explicitly in flake.nix
- Keep module implementations in separate files, not in flake.nix's config section
- Use descriptive variable names (`cfg` for `config.my.<namespace>`)
