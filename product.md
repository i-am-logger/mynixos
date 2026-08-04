# mynixos -- Product Overview

## Product Vision

mynixos is a typed functional DSL for NixOS and nix-darwin configuration. It provides a `my.*` namespace that turns system configuration into a composable, type-safe API. Instead of writing raw NixOS or nix-darwin modules, users declare intent through structured options -- and mynixos handles the implementation.

The core proposition: **defaults that work, and `mkDefault` so a host can disagree.** Opinionated choices are overridable, with one deliberate exception: `graphical.enable` is forced on macOS, because a Mac cannot not be graphical. User configuration lives separately, in a consumer flake; mynixos provides only types, options, and implementations.

A single `mkSystem` call assembles hardware, users, secrets, home-manager and -- on NixOS -- filesystems into a complete system, on either platform.

## Platforms

One DSL, two evaluators:

| `platform`         | Evaluator                        | Module set                                     |
|--------------------|----------------------------------|------------------------------------------------|
| `"linux"` (default)| `lib.nixosSystem`                | `nixosModules.default` -> `platforms/linux.nix` |
| `"darwin"`         | `nix-darwin.lib.darwinSystem`    | `darwinModules.default` -> `platforms/darwin.nix` |

Platform reach is **structural**. An option is declared in the file that implements it, and the `platforms/*.nix` that imports that file decides where the option exists. Nothing tests `pkgs.stdenv.hostPlatform.isDarwin` to decide reach, so setting a NixOS-only option on a Mac is

```
error: The option `my.security' does not exist.
```

The message names the outermost undeclared attribute rather than the leaf that was
set, because that is where matching stops.

rather than a silent no-op -- and a module imported only by `platforms/darwin.nix` needs no platform guard at all. `tests/user-option-reach.nix` enumerates both option trees and fails when a one-sided option is not accounted for, with a reason recorded for each.

## Domain Model

### Cross-platform

- **`my.system`** -- Hostname, `flakeDir` (where the rebuild/test/build scripts look for this host's flake), the unfree allowlist that modules append to, and the master switch for core system utilities.
- **`my.users`** -- Per-user configuration: feature flags, apps, environment selectors, theming, input preferences, secrets, mounts, security keys. A user entry is *active* -- created as an account on NixOS, given a home directory on macOS -- only when `fullName` is defined; entries without it carry data (mounts, email, YubiKeys) that other modules read.
- **`my.hardware`** -- `cpu` and `gpu` vendor metadata (`amd` / `intel` / `apple`, plus `nvidia` for the GPU) and `audio`. Everything bus- or vendor-specific is declared next to its implementation, so it exists only where it can act.
- **`my.fonts`** -- System font packages. Empty means the mynixos default, a Nerd Font, because waybar, starship and the shell prompts draw glyphs from its private-use range.
- **`my.dev`** -- Development infrastructure. `my.dev.enable` is auto-derived from user `dev.enable`, and `my.dev.docker` carries the settings that belong to the machine rather than an account (`autoStart`, the darwin Colima launchd agent). Whether Docker is installed for a person is the per-user `my.users.<name>.dev.docker.enable`, and that one option reads the same on both platforms: `virtualisation.docker` on NixOS, Colima on macOS.
- **`my.secrets`** -- sops-nix integration (age keys, SSH keys, GnuPG/YubiKey decryption).

### NixOS

- **`my.security`** -- Secure boot (lanzaboote), TPM2 measured-boot setup, audit rules. Policy only: authentication *devices* live under `my.hardware`.
- **`my.graphical`** -- Graphical environment: Hyprland, display manager, XDG portals. Auto-enabled when any user sets `graphical.enable = true`.
- **`my.ai`** -- Ollama (ROCm / CUDA / CPU acceleration), claude-code-proxy, openclaw. Auto-derived from user `ai.enable`.
- **`my.streaming`** / **`my.video`** -- OBS Studio and polkit rules; v4l2loopback virtual video devices, auto-enabled by streaming.
- **`my.performance`** -- Kernel tunables, zram compressed swap, vmtouch RAM caching.
- **`my.environment`** -- Environment variables, XDG portals, locale, timezone, display manager (greetd / GDM / SDDM / LightDM), MOTD, default editor and browser.
- **`my.theming`** -- vogix runtime theme management, the hypr-vogix monochromatic screen overlay, and OpenRGB hardware lighting.
- **`my.storage`** / **`my.filesystem`** -- Impermanence (tmpfs root, persist path, ccache, flake-repo cloning, user data persistence) and the filesystem type (`"disko"` for declarative partitioning, `"nixos"` for standard) with its config path.
- **`my.network`** -- openssh, tailscale, headscale, tor, unifi, service monitoring, IPv6 privacy extensions.
- **`my.infra`** -- k3s Kubernetes cluster, and the GitHub Actions Runner Controller stack (with optional GPU passthrough) on top of it.
- **`my.forensics`** -- Crash and fault diagnostics: retained ambient system log, coredumps, GPU faults, collected under `/var/log/forensics`.
- **`my.presets`** -- The workstation preset, which turns on the system, environment and performance domains.
- **`my.boot`** -- UEFI boot.

Hardware areas that exist only here: `bluetooth`, `cooling`, `memory`, `motherboards`, `peripherals`, `securityKeys`, `storage`, `usb`, and the Lenovo laptop profiles. `my.system` also gains `architecture`, `kernel`, `udev`, `systemd`, `dualBoot` and `persistence`.

### macOS

- **`my.homebrew`** -- Mac App Store apps and the few casks Nix genuinely cannot package. `cleanup` uninstalls what is not declared, which is what makes it declarative rather than additive.
- **`my.nixGc`** -- Periodic garbage collection as plain launchd daemons. nix-darwin asserts that its own `nix.gc.automatic` requires `nix.enable`, which is false on a host where Nix stays owned by the installer.
- **`my.network.sshFirewall`** -- A default-deny inbound pf ruleset, the macOS counterpart to NixOS's `networking.firewall`. Its allows key on the tailnet's *address* ranges (`100.64.0.0/10`, `fd7a:115c:a1e0::/48`) rather than on an interface: the Tailscale tunnel has no stable name among a Mac's many `utun*` devices, and addressing survives a move to a self-hosted headscale. `sshd_config`'s `ListenAddress` does nothing on macOS because launchd owns the socket, and the application firewall filters per application with no allowlist, so neither can express "deny inbound except SSH from the tailnet".
- **`my.hardware.biometrics`** -- Touch ID for `sudo` (with `pam_reattach`, so it works inside a terminal multiplexer) and Apple Watch proximity unlock.
- **`my.hardware.laptops.apple`** -- Apple Silicon laptop profiles; enabling one is what sets `nixpkgs.hostPlatform`.

## Architecture

### Module Pattern

Every module follows a consistent structure:

```
my/category/item/
  options.nix    -- Type definitions (mkOption, mkEnableOption, submodules)
  default.nix    -- Implementation (mkIf, mkMerge for conditional config)
  mynixos.nix    -- Opinionated defaults (mkDefault values, optional)
```

Options define the contract. Implementations map those options to NixOS / nix-darwin / home-manager config. Opinionated defaults wire up sensible choices that users can override.

The filename carries the role, and a platform variant keeps the role in its name: `mynixos-darwin.nix` is a defaults injector that only darwin loads, while `my/users/users/darwin.nix` sits beside `default.nix` and is therefore an implementation.

### Composition

`platforms/common.nix`, `platforms/linux.nix` and `platforms/darwin.nix` are the single source of truth for what a mynixos system is made of. Both platform files import `common.nix` and add their own option declarations, opinionated defaults and implementations. `flake.nix` wraps them:

```
nixosModules.default  = platforms/linux.nix  + impermanence + lanzaboote
darwinModules.default = platforms/darwin.nix + nix-homebrew
```

Those three are flake input *values* rather than paths, which is why they are listed in `flake.nix` and not in the platform files. Beyond them, `flake.nix` keeps only the hardware-profile paths it exports as `lib.hardware`.

A module belongs in `common.nix` when it both evaluates and is meaningful on both platforms. Modules that are structurally portable -- they emit only `home-manager.users.*` -- but whose packages are Wayland/X11-only live in `linux.nix`, where they buy the same thing at no evaluation risk.

### System Assembly (mkSystem)

`mkSystem` is the entry point, for both platforms. It accepts:

| Parameter      | Purpose                                                                  |
|----------------|--------------------------------------------------------------------------|
| `platform`     | `"linux"` (default) or `"darwin"` -- selects the evaluator and module set |
| `hostname`     | System hostname (alternatively set `my.system.hostname`)                  |
| `hardware`     | Hardware module paths to prepend to the module list                      |
| `users`        | User definitions (`name` and `homeManager`; `nixosUser` on NixOS)         |
| `my`           | `my.*` configuration -- one attrset, or a list of layers                  |
| `config`       | Additional platform config path                                           |
| `extraModules` | Additional modules                                                        |

In-tree hardware profiles are already part of the platform module set, so a host turns one on through its option (`my.hardware.motherboards.gigabyte.…`, `my.hardware.laptops.apple.…`); the `hardware` parameter is for profiles that live outside mynixos.

There is no `system` argument on either platform: the architecture comes from the hardware profile, which sets `nixpkgs.hostPlatform`. On darwin `mkSystem` asserts that `platform` and the resolved `hostPlatform` agree, so a host that enabled no darwin profile fails with an explanation instead of producing a subtly wrong system. Arguments that cannot mean anything on darwin are rejected rather than ignored: `my.filesystem` throws, because disko does not manage APFS.

What a system is made of, in order:

1. `hardware` module paths
2. The platform module set (`nixosModules.default` / `darwinModules.default`)
3. NixOS only: filesystem modules, selected by `my.filesystem.type` (disko + the imported device config, or a plain NixOS filesystem module)
4. The optional `config` path
5. Hostname (`networking.hostName`; on darwin also `localHostName` and `computerName`)
6. Per-user system modules (`nixosUser`, or an optional `darwinUser`), then home-manager
7. sops-nix
8. The `my` layers
9. `extraModules`

### `my` as Layers

`my` may be a list. Each element becomes its own module, so overlapping definitions are merged by the module system rather than by `//`: `listOf` options concatenate, and two different values for one scalar are a hard error instead of a silent last-wins. That is what lets a host contribute its own facts -- its GitHub repositories, its mounts -- without reaching into a shared user profile and re-splicing it by hand.

A flattened read-only view exists for the handful of decisions made before any module evaluates (hostname resolution, the darwin rejections). It never produces configuration.

### Per-User Platform Tiers

`my.users.<name>` is authored in the consumer's repo as plain Nix -- an attrset, not a module -- so it has no `mkIf` to express "only on this platform". `linux` and `darwin` are therefore reserved keys inside a user entry, holding values that apply on that platform alone. `mkSystem` collapses them before any module evaluates, so `my.users.<name>.darwin` is not an option path and never becomes one. A misspelt tier is not stripped: it lands in the shared layer and fails as an unknown option.

### Option Flow

```
options.nix  -->  platforms/*.nix (mkOptionsModule)  -->  my.* namespace available
                                                              |
default.nix  -->  platforms/*.nix (imports list)     -->  reads config.my.*, produces
                                                          NixOS / nix-darwin config
                                                              |
mynixos.nix  -->  platforms/*.nix (imports list)     -->  injects mkDefault values
                                                          into user submodules
```

### App Configuration Model

Apps are per-user, structured as `my.users.<name>.apps.<group>.<category>.<app>`. `lib/mk-app.nix` collapses the home-manager boilerplate, and an app declares its own option in the same file:

```nix
args:

(import ../../../../../lib/mk-app.nix).mkApp args {
  path = "terminal.viewers.bat";
  option = {
    name = "bat";
    default = false;
    description = "Bat file viewer";
  };
  home = _: { programs.bat.enable = true; };
}
```

Spec fields are `path` (dotted path under `userCfg.apps`), `option` (an `mkAppOption` spec), `home` (the per-user home-manager config, receiving the module args extended with `cfg`, `userCfg`, `name` and `pkgs`), and `unfree` (package names added to `my.system.allowedUnfreePackages` when any user enables the app).

Declaring the option from the same file is what makes platform reach enforceable and a path typo unrepresentable: the declaration and the read are built from the same `path` string, and the `platforms/*.nix` that imports the file decides both at once. App modules that are not `mkApp` calls -- a hand-written implementation, or one split across two platform-specific files -- declare their option in a sibling `options.nix` beside it, for the same reason.

`mkAppOption` gives every app a uniform interface:

- `.enable` -- Whether the app is active
- `.persisted` -- Whether to persist app data (default: true)
- `.persistedDirectories` -- Directories to persist (relative to home)
- `.persistedFiles` -- Files to persist (relative to home)
- App-specific extra options (e.g. Hyprland gaps and border size, bash history size)

The persistence aggregation pipeline (`my/storage/impermanence/aggregation.nix`) recursively walks the whole `apps` tree -- any attrset carrying an `enable` field is treated as a leaf app -- and collects the `persistedDirectories` / `persistedFiles` of every app that is both enabled and persisted.

### Feature Bundle Auto-Derivation

System-level features auto-derive from user flags:

```
user.graphical.enable = true  -->  my.graphical.enable = true (system)
user.dev.enable = true        -->  my.dev.enable = true (system)
user.ai.enable = true         -->  my.ai.enable = true (system)
user.graphical.streaming      -->  my.streaming.enable + my.video.virtual.enable
```

### Persistence Aggregation

Apps declare their persistence paths; the aggregation pipeline collects them (NixOS only):

```
app.persistedDirectories  -->  aggregation.nix   -->  my.system.persistence.aggregated
feature module config     ------------------------->  my.system.persistence.features
both                      -->  impermanence.nix  -->  environment.persistence
                                                      (nix-community/impermanence)
```

The two halves get there differently. `aggregated` is *computed*: it is `readOnly`
top to bottom, and `aggregation.nix` is the one module that writes it, from the
per-user `apps` tree. `features` is a *collection point*: three plain `listOf`
options (`systemDirectories`, `userDirectories`, `userFiles`) that every module
owning state appends to from its own `config` -- `my/network/tailscale`,
`my/dev/development`, `my/hardware/security-keys/yubico`, `my/secrets/linux.nix`
and the Linux-only app siblings among them -- with the module system concatenating
the definitions. A cross-platform module contributes from a Linux-only sibling, so
nothing writes an option that does not exist on darwin.

## Current State

### Flake Outputs

- **`nixosModules.default` / `darwinModules.default`** -- the `my.*` namespace on each platform.
- **`lib`** -- `mkSystem`, `mkInstallerISO`, `mkApp`, `activeUsers`, the `securityKeys` type constructors, and the `hardware` profile paths.
- **`checks`** -- Linux only (`x86_64-linux`, `aarch64-linux`). Most of `tests/` builds a real `lib.nixosSystem` for the given system, which is meaningless on darwin, so a half-broken `nix flake check` is not shipped there.
- **`formatter`, `devShells`, `apps`** -- also `aarch64-darwin`. None of them builds a NixOS system, and this repo is edited from a Mac.
- **`tests`** -- the heavy booting VM test, kept out of `checks` so `nix flake check` stays light and KVM-free.

### CI/CD Pipeline

Single workflow (`ci-and-release.yml`) on every PR and push to master:

1. **Nix Flake Check** -- `nix flake check --print-build-logs` (includes treefmt formatting and the pre-commit hooks)
2. **Nix Lint** -- `statix check .` + `deadnix --fail .`
3. **Module Coverage** -- `scripts/module-coverage.sh --lcov`, uploaded to Codecov. It scrapes `platforms/*.nix` for imported module paths, since that is where modules are actually imported.
4. **Release Please** -- Automated versioning and changelog on master, after the three above

Pre-commit hooks (via git-hooks.nix): treefmt, statix, deadnix.

### Release Management

- **release-please** with manifest-based config
- Conventional commits drive versioning (feat = minor, fix = patch, refactor = minor)
- Version tracked in `version.txt` and `.release-please-manifest.json`
- Changelog sections: Features, Bug Fixes, Code Refactoring, Documentation, Miscellaneous

### External Dependencies

| Dependency     | Purpose                          | Source                        |
|----------------|----------------------------------|-------------------------------|
| nixpkgs        | Package set                      | nixos-unstable                |
| home-manager   | User environment                 | Custom fork (webapps-module)  |
| nix-darwin     | macOS system configuration       | nix-darwin/nix-darwin         |
| nix-homebrew   | Declarative Homebrew install     | zhaofengli/nix-homebrew       |
| disko          | Declarative disk partitioning    | nix-community/disko           |
| impermanence   | Tmpfs root + persistent storage  | nix-community/impermanence    |
| lanzaboote     | Secure boot                      | nix-community/lanzaboote      |
| sops-nix       | Secrets management               | Mic92/sops-nix                |
| vogix          | Runtime theme management         | i-am-logger/vogix             |
| hypr-vogix     | Monochromatic Hyprland overlay   | i-am-logger/hypr-vogix        |
| treefmt-nix    | Formatter orchestration          | numtide/treefmt-nix           |
| git-hooks      | Pre-commit hooks                 | cachix/git-hooks.nix          |

nix-darwin follows this repo's nixpkgs: the two must agree on nixos-render-docs' CLI, whose flags move between releases. nix-homebrew is what actually installs Homebrew -- nix-darwin's own `homebrew.*` module only writes a Brewfile and runs `brew bundle`.

## Quality Metrics

### Type Safety

- **Typed:** All `my.*` options use `mkOption` with explicit types (enum, submodule, bool, int, str, package, path, listOf, attrsOf, constrained floats). Hardware CPU/GPU are enums, as are the filesystem type (`"disko"` | `"nixos"`) and the display manager. The app-level `persistedDirectories` / `persistedFiles` that `mkAppOption` generates use a checked relative-path type that rejects absolute paths and `..`.
- **Structured:** Apps use `mkAppOption` for uniform interface generation with typed extra options.
- **Gaps:** A few options use `lib.types.attrsOf lib.types.anything` for passthrough -- Hyprland's `extraSettings`, and the `settings` field on the per-user program selectors -- because they land in home-manager `programs.<name>` modules whose schemas differ per program and are validated downstream. The `graphical.webapps` and `graphical.media` toggles are bare `lib.types.bool` without `mkAppOption` structure.

### Test Coverage

Eval tests, run as `checks`. These evaluate the module system rather than building a closure -- fast, no VM, no KVM:

- `module-eval.nix` -- modules evaluate, forcing the four places module config lands: system packages, per-user home-manager package sets, systemd unit names, created accounts.
- `type-validation.nix` -- accept/reject of typed options via `tryEval`. Each rejection accessor is first run against a valid config, so a deleted option turns the test red instead of silently green.
- `integration-smoke.nix` and `persistence-and-edge-cases.nix` -- realistic configs evaluate; feature-derivation and persistence-aggregation assertions.
- `real-system-pkgs.nix` -- evaluates a system the way `mkSystem` does, with `pkgs` *not* in `specialArgs`, so `mkApp`'s pkgs sourcing is genuinely exercised.
- `user-option-reach.nix` -- asserts which `my.*` options each platform declares, and that every one-sided prefix is listed with a reason.
- `mksystem.nix` -- platform dispatch, argument rejection, `my` layering, and the per-user `linux` / `darwin` tiers.
- `darwin-smoke.nix` -- the darwin module set, evaluated. Only `config` is read, never a derivation, so a Linux runner covers it without an aarch64-darwin builder.

Booting VM test (`tests/vm-system.nix`): a real `pkgs.testers.runNixOSTest` that BOOTS a qemu VM and asserts runtime behaviour eval cannot see -- active user creation, the `activeUsers` filter excluding partial users, home-manager activation, feature-derived group membership, login-shell mapping, and that the `mkApp` pipeline installs app binaries into the user profile. Heavy (needs `/dev/kvm`), so it is run on demand: `nix build .#tests.<system>.vm-system -L`.

Static analysis: statix (anti-pattern detection) and deadnix (dead code detection) run on every PR.

### Code Quality

- Formatting enforced via treefmt (nixpkgs-fmt, shfmt, shellcheck, yamlfmt).
- Nothing is discovered by scanning the filesystem. A `platforms/*.nix` is always the entry point; the few modules that pull in siblings name them in their own `imports`.
- Hardware profiles restate the category toggles they drive (bluetooth, storage, USB) and forward them to the generic driver options, so those options are declared in two shapes.

## Roadmap

Development priorities are tracked as GitHub issues on the repository.

## Design Principles

### Opinionated Defaults with User Override

Opinionated choices use `mkDefault`, which has lower priority than a direct assignment, so a host overrides them by stating what it wants. The one exception is `graphical.enable` on macOS, which is `mkForce` because the platform has no headless variant:

```nix
# mynixos sets (my/users/terminal/mynixos.nix, when terminal.enable = true):
apps.terminal.viewers.bat.enable = lib.mkDefault true;
# User overrides (takes priority):
apps.terminal.viewers.bat.enable = false;
```

### Platform Reach Is Structural

An option lives in the file that implements it, and the composition layer decides which platforms load that file. A platform-scoped option therefore does not exist elsewhere, and setting it is the module system's own error. Attaching a nicer message by declaring a stub with `apply = _: throw ...` would be strictly worse: the option would exist, and `apply` only fires when something reads it -- so nothing would fire.

### Per-User App Configuration

Apps are scoped per-user, not per-system. Two users on the same machine can have different app sets, different shells, different editors.

### Feature Bundles

Feature bundles (`terminal`, `graphical`, `dev`, `ai`) activate curated sets of apps. Each bundle's `mynixos.nix` defines which apps are enabled by default when the bundle is active; apps whose answer differs by platform are defaulted from `mynixos-linux.nix` / `mynixos-darwin.nix`. Individual apps remain independently toggleable.

### System-Level Auto-Derivation

System services are never configured directly by users. When any user enables a feature (e.g. `graphical.enable = true`), mynixos enables the corresponding system-level service -- Hyprland, display manager, Docker, Ollama.

### Persistence Aggregation

Apps declare what they need persisted. The aggregation pipeline collects those declarations across all users and all apps, then configures impermanence in one place. This eliminates manual persistence management.

### Module Pattern

Separation of concerns at the file level: types are separate from implementation, and both are separate from opinionated defaults. This makes it possible to use mynixos types without mynixos opinions.
