# Changelog

All notable changes to mynixos will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.0.0 (2026-03-12)


### Features

* Add backward-compatible namespace aliases for core and motd ([f9851b1](https://github.com/i-am-logger/mynixos/commit/f9851b1702b69225b399016820f00506c29d170c))
* add claude-code module, fix Hyprland compat, update flake inputs ([a1d3690](https://github.com/i-am-logger/mynixos/commit/a1d3690627ddcbabd0698fa27b33547b94b23a6d))
* Add cooling module options to flake.nix ([ec91cf0](https://github.com/i-am-logger/mynixos/commit/ec91cf0d60942af7ae0191baa6553117c1144a20))
* add HDMI audio EDID firmware and update hyprland config ([c945c56](https://github.com/i-am-logger/mynixos/commit/c945c56239044717068f0d3613ef841dfe8a9cb6))
* Add my.hardware namespace for motherboards, laptops, and cooling ([6926cbb](https://github.com/i-am-logger/mynixos/commit/6926cbbe4408791efbefb5c89913ead2ecefe1c6))
* Add user creation support with groups, avatar, and password ([ecea621](https://github.com/i-am-logger/mynixos/commit/ecea62124ae010a497e88b0000e36971554bdc48))
* Add user-level media and terminal feature categories ([27ee547](https://github.com/i-am-logger/mynixos/commit/27ee547be79ae40a788b30adeef655f9c8f40644))
* add vogix theming support and update vogix input to GitHub ([07c4418](https://github.com/i-am-logger/mynixos/commit/07c441817d6dc03c6787bf69d5010e39e46cdfab))
* added support for ccache ([f247bab](https://github.com/i-am-logger/mynixos/commit/f247bab87d80bfa7c0adb85ad6724cd9fbf381a6))
* change distribution name from nixos to mynixos ([eaa9f00](https://github.com/i-am-logger/mynixos/commit/eaa9f0047616d6769d0764be351915f1db27e430))
* Consolidate development tools and improve opinionated defaults ([a916f3d](https://github.com/i-am-logger/mynixos/commit/a916f3d97209e0a8edd163744d0df0884811cff1))
* github-runner auto-enables k3s directly, no manual setup needed ([f6dd503](https://github.com/i-am-logger/mynixos/commit/f6dd503d3886e6428c44d7b39cfa99a9d6ae4115))
* Hardware module restructuring with composable components ([57f177e](https://github.com/i-am-logger/mynixos/commit/57f177e630f6fe42de100c6426dd3cda24098d1d))
* **hardware:** Add NZXT Kraken Elite 240 RGB cooling module ([6405ddd](https://github.com/i-am-logger/mynixos/commit/6405dddefc9b740bae300f2a5bcfb5d60d6b83ad))
* initial mynixos implementation with typed functional DSL ([e094d09](https://github.com/i-am-logger/mynixos/commit/e094d0982194da2e703881c88017f326fdfc693e))
* Motherboard/laptop modules automatically set cpu/gpu/bluetooth/audio ([58de6ef](https://github.com/i-am-logger/mynixos/commit/58de6ef580f6a7b2095c899e8dd105e42b9ab900))
* Move element to user-level configuration ([1ffaf6c](https://github.com/i-am-logger/mynixos/commit/1ffaf6ccf8ce81febd9f7c899dd297c29eea8301))
* Move GitHub config to user.github namespace ([17f5ce4](https://github.com/i-am-logger/mynixos/commit/17f5ce4b04023fd870b81e5e5314e94360d194e2))
* Move signal and slack to user-level configuration ([0da4205](https://github.com/i-am-logger/mynixos/commit/0da4205b8959252700d8e9b1d311deffb2c69ee6))
* Move terminals (kitty, ghostty, wezterm) to user-level ([41931d4](https://github.com/i-am-logger/mynixos/commit/41931d4d78c7f938dab0a11e110e57beacab80f7))
* Populate read-only system flags in graphical/dev/streaming ([f2de256](https://github.com/i-am-logger/mynixos/commit/f2de256ab489633c4d91a795d7c0ef05fa31c451))
* Replace GDM with greetd for minimal Hyprland setup ([253daa2](https://github.com/i-am-logger/mynixos/commit/253daa2ef06f8c7b46ce680c944c53f84203c197))


### Bug Fixes

* add home.activation to automatically import YubiKey GPG keys ([c5dcbca](https://github.com/i-am-logger/mynixos/commit/c5dcbcaeb497ad19a7d9ed29123a731308a38d5b))
* Add my.video.streamdeck namespace and fix streaming module ([cd1130b](https://github.com/i-am-logger/mynixos/commit/cd1130b10039aade009a266cceadac59ffcc18e9))
* Address critical audit findings and add migration plan ([10a4533](https://github.com/i-am-logger/mynixos/commit/10a4533570bde553e3ba70af55a73cfbb1ad5db0))
* Complete architectural refactoring of mynixos (16 fixes across 3 rounds) ([46e5e42](https://github.com/i-am-logger/mynixos/commit/46e5e42192865f5e9aa2d6b14d10dd9d7588d58c))
* disable stylix module due to nixpkgs compatibility issues ([913d8c0](https://github.com/i-am-logger/mynixos/commit/913d8c020e36984de01bbd44e9b23517f4f10322))
* fix app persistence aggregation and distribute hardcoded paths to modules ([a88066a](https://github.com/i-am-logger/mynixos/commit/a88066acf95f99ef7931abf34a3c53f8c75203c4))
* fix CI by removing installer-iso job and formatting nix files ([5281c50](https://github.com/i-am-logger/mynixos/commit/5281c50cd4b3032a913ea1fe47fb030e8b36a5eb))
* Fix laptop module syntax and structure ([1e1ac62](https://github.com/i-am-logger/mynixos/commit/1e1ac62a486d1a0175be36b43215e83429d2b877))
* make cava stylix theming conditional on themes being enabled ([e0d9458](https://github.com/i-am-logger/mynixos/commit/e0d94586e67ce40243d64d488a53423abc6754a2))
* make cava-extended module work when stylix is disabled ([6e8eb4f](https://github.com/i-am-logger/mynixos/commit/6e8eb4fe3448e1ce06c797c9d7255060280589d2))
* Make v4l2loopback kernel module conditional on my.video.virtual.enable ([515cd7d](https://github.com/i-am-logger/mynixos/commit/515cd7d7900cbbc1a1d7581a0e480404597fc9be))
* Merge duplicate environment.systemPackages in github-runner ([e767c9d](https://github.com/i-am-logger/mynixos/commit/e767c9ddf20bee4ed1b8b6ab063e0ebab027d987))
* Merge duplicate systemd.services in github-runner ([227c508](https://github.com/i-am-logger/mynixos/commit/227c50854076546ed55281eb7db20244009e6e23))
* Move enable check into hardware directory modules ([061c097](https://github.com/i-am-logger/mynixos/commit/061c097f2118987484d585f2869608895ea13c9a))
* only disable identitiesOnly when YubiKey is present ([303aea8](https://github.com/i-am-logger/mynixos/commit/303aea8e30d5777188528b293e6634f23eb56ea6))
* Prevent infinite recursion in github-runner by requiring development to be enabled ([b99fcf7](https://github.com/i-am-logger/mynixos/commit/b99fcf706222498af1cc019e9f6e3dafdf7ba286))
* Remove conflicting greetd settings merge ([f2e90be](https://github.com/i-am-logger/mynixos/commit/f2e90be1fa89463685c8be1c874c2007c4e85303))
* Remove deprecated modules/ directory ([d7cd3da](https://github.com/i-am-logger/mynixos/commit/d7cd3da1600496a1f1a75d69488c31c7f472c8c0))
* Remove duplicate config (vm.max_map_count, NetworkManager, usbmuxd) ([73de1a0](https://github.com/i-am-logger/mynixos/commit/73de1a058de199be50564aff90ef373b8ba9b1cb))
* Remove duplicate xdg-desktop-portal-hyprland from home packages ([5ee9c5c](https://github.com/i-am-logger/mynixos/commit/5ee9c5c1f59f82c2b8c17954719b265309fccc3b))
* Remove extra closing paren in laptop module ([93563cd](https://github.com/i-am-logger/mynixos/commit/93563cda756a3c78c238f2724bc84791a386bce1))
* Remove k3s config from github-runner, only assert it's enabled ([9be0e0d](https://github.com/i-am-logger/mynixos/commit/9be0e0d5b705d3c96d7504ae8be2c5d921e8fbb3))
* Remove option definitions from CPU/GPU modules to avoid type conflicts ([9bbec68](https://github.com/i-am-logger/mynixos/commit/9bbec687407063497d17e524bd9865258763cd6d))
* Remove ROCm config from motherboard module to avoid attribute conflict ([385866b](https://github.com/i-am-logger/mynixos/commit/385866b80e582eca4e495966b834dd188f243eff))
* Resolve configurationLimit conflict in Legion laptop ([492f914](https://github.com/i-am-logger/mynixos/commit/492f914cf417fd1e758e9a3b165d02fca0e20b21))
* Resolve infinite recursion and undefined cfg in development.nix ([ef95007](https://github.com/i-am-logger/mynixos/commit/ef9500768fba876ca2f6ef2da135f124f7eb9232))
* set CCACHE_DIR system-wide for user ccache access ([87fbac6](https://github.com/i-am-logger/mynixos/commit/87fbac63abe424c9d92d6d5bce8a7b722ebd3606))
* set identitiesOnly = false for GitHub/GitLab/BitBucket to allow gpg-agent SSH keys ([50d9490](https://github.com/i-am-logger/mynixos/commit/50d9490cab300d001045cf150e0344398615a7c5))
* Standardize browser option to types.package for consistency ([42efeea](https://github.com/i-am-logger/mynixos/commit/42efeea49f2d52e624329b5d727ff8d5001ac2d0))
* Update home-manager and fix deprecated options ([ecb4f29](https://github.com/i-am-logger/mynixos/commit/ecb4f294c4fd06a3093d60e1344ef75b7ef11a75))
* Update home-manager deprecated options and add missing applications ([dbc6de2](https://github.com/i-am-logger/mynixos/commit/dbc6de2d113e2ac13ca5b8049936d4ae512b5ae9))
* Update infra modules to use new flattened paths ([69c1bad](https://github.com/i-am-logger/mynixos/commit/69c1bad4c716eb843f25661de1b9c7be902458cc))
* Use conditional imports for hardware wrapper modules ([d4da82a](https://github.com/i-am-logger/mynixos/commit/d4da82a876d39b6a43d330be35496a67a5e36f26))
* use mkDefault for networking.wireless.enable to avoid conflicts ([2464f18](https://github.com/i-am-logger/mynixos/commit/2464f1864553b7a49566af0bdb873b8cdf6ea7df))
* Use regular priority for environment variables to override nixpkgs defaults ([2d3ec4c](https://github.com/i-am-logger/mynixos/commit/2d3ec4cc5493a9e40461f3db448f52c937c11676))
* use systemd user service instead of home.activation for GPG key import ([4ae6d7a](https://github.com/i-am-logger/mynixos/commit/4ae6d7abe5cc6d0c232ed86c0c62175afb3f4c4d))
* **users:** Add missing home and group settings for created users ([872faca](https://github.com/i-am-logger/mynixos/commit/872faca56a58ff0e285c0afb16279d9fc264c902))

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
