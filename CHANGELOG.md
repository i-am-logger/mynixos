# Changelog

All notable changes to mynixos will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed (BREAKING CHANGE)

- **Removed `my.apps.*` namespace** - Use `my.users.<name>.apps.*` instead
  - The system-level `my.apps` namespace has been removed to eliminate duplication and confusion
  - All app configurations are now per-user via `my.users.<name>.apps.*`
  - This reduces flake.nix by 205 lines and provides clearer semantics
  - **Migration:** Change `my.apps.browsers.brave` to `my.users.<your-name>.apps.browsers.brave`
  - **Rationale:** Apps are inherently user preferences, not system-wide settings
  - Related fixes: alacritty and warp terminal modules now properly check per-user config

### Fixed

- **Terminal app namespace bugs** (alacritty, warp)
  - Fixed modules incorrectly using system-level `config.my.apps.terminals`
  - Now properly check per-user `userCfg.apps.terminals.*`
  - Prevents apps from being installed globally when only one user enables them

- **Removed deprecated options**
  - `my.hostname` (use `my.system.hostname`)
  - `my.users.<name>.githubUsername` (use `my.users.<name>.github.username`)
  - `my.users.<name>.editor` string (use `my.users.<name>.environment.editor` package)
  - `my.users.<name>.browser` string (use `my.users.<name>.environment.browser` package)

- **Impermanence Firefox persistence**
  - Changed from checking `config.my.apps.browsers.firefox` (wrong namespace)
  - Now unconditionally persists `.mozilla` directory (simpler and more reliable)

- **StreamDeck installation scope**
  - Changed from installing for ALL users when hardware enabled
  - Now only installs for users with `graphical.streaming.enable = true`
  - Prevents unnecessary packages for non-streaming users

### Added

- **Complete flake.nix Migration (Phases 1-4)**
  - **Phase 1**: Removed `my.apps.*` namespace (-205 lines)
  - **Phase 2**: Extracted all system options to 17 organized files (-1,528 lines)
  - **Phase 3**: Split users.nix into 10 specialized subdirectory files
  - **Phase 4**: Created reusable app option library (lib/app-options.nix)
  - **Final result**: flake.nix reduced from 2,018 to 259 lines (87.2% reduction)
  - **Total extracted**: 1,906 lines across 28 organized option files

- **New Directory Structure**
  - `options/` - All option definitions organized by namespace
  - `options/users/` - User-specific options in 10 focused files
  - `lib/app-options.nix` - Reusable library for app option patterns
  - Clean separation of concerns and improved maintainability

- **FLAKE_MIGRATION_PLAN.md**
  - Comprehensive plan for extracting flake.nix option definitions
  - All phases successfully completed
  - Exceeded targets (goal: 800-1000 lines, achieved: 259 lines)

## [0.1.0] - 2025-12-06

### Added

- Initial release of mynixos typed functional DSL
- Comprehensive hardware auto-detection (motherboards, laptops, CPUs, GPUs, peripherals)
- Feature-based configuration system (graphical, dev, ai, streaming, security)
- User-level configuration with opinionated defaults
- Impermanence support with automatic persistence
- YubiKey integration for SSH and GPG
- Secure boot support via Lanzaboote
- K3s and GitHub Actions runner infrastructure
- Stylix theming integration
- Home-manager integration with per-user packages
- AMD ROCm support for AI workloads (Ollama)
- OBS Studio streaming setup with virtual camera
- Hyprland window manager with opinionated defaults

---

**Note:** This project follows the philosophy that the API is unstable during initial development.
Breaking changes are acceptable and will be documented in this changelog.
