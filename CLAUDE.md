# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

mynixos is a typed functional DSL for system configuration. It exposes a `my.*` namespace of strongly-typed
options and builds both NixOS and nix-darwin systems from one entry point. mynixos provides the types, options
and implementations; a consumer flake (see [github.com/i-am-logger/flake](https://github.com/i-am-logger/flake))
provides the data — hosts, users, secrets.

## Build Commands

```bash
nix fmt                                   # treefmt: nixpkgs-fmt, shfmt, shellcheck, yamlfmt
nix flake check                           # evaluate the check suite
nix build .#tests.<system>.vm-system -L   # booting VM test, on demand (needs /dev/kvm)
```

`checks` and `tests` are declared for `x86_64-linux` and `aarch64-linux` only — most of `tests/` builds a real
`lib.nixosSystem`, which is meaningless on darwin. `formatter`, `devShells` and `apps` additionally cover
`aarch64-darwin`, so the repo can be edited, formatted and linted from a Mac.

On `aarch64-darwin`, `nix flake check` stops at `apps.aarch64-darwin.demo-hypr-vogix`, whose packages are
Linux-only. `nix fmt` and `nix develop` work there.

CI (`.github/workflows/ci-and-release.yml`) runs `nix flake check`, `statix check .`, `deadnix --fail .`, and
`scripts/module-coverage.sh --lcov` on every PR. `checks.formatting` is treefmt and `checks.pre-commit` is the
git-hooks bundle (treefmt + statix + deadnix), so `nix flake check` covers formatting and linting too.

## Core Architecture

### Composition lives in `platforms/`

`platforms/{common,linux,darwin}.nix` is the single source of truth for what a mynixos system is made of.
`linux.nix` and `darwin.nix` each import `common.nix` and add their own modules.

- `nixosModules.default` = `platforms/linux.nix` + the impermanence and lanzaboote modules.
- `darwinModules.default` = `platforms/darwin.nix` + nix-homebrew.
- Those three are named in `flake.nix` because they are flake input *values*, not paths.
- `flake.nix` holds inputs, the `lib` export, the hardware-profile paths, checks and dev outputs — not the
  module list.

`platforms/oci.nix` is a fourth file, and deliberately not a fourth *platform*: it imports `linux.nix`
wholesale and overrides the host defaults a container cannot honour. Importing the whole thing is the point —
`mkIf false` still requires an option to be **declared**, so a role that never boots a bootloader must still
carry lanzaboote's and impermanence's declarations or every host module that mentions them fails to evaluate.
What it overrides is the small set of things `linux.nix` turns on for a laptop and a container has no business
running: openrgb, audio, sshd, systemd-oomd, the flake registry, and `/run/wrappers` as a mount.

### Platform reach is structural

**This is the invariant not to break.** An option is declared in the file that implements it, and which
`platforms/*.nix` imports that file decides on which platform the option exists at all. A darwin host setting a
Linux-only option gets a hard error from the module system rather than a silent no-op. The message names the
outermost attribute that is not declared, not the leaf that was set, so `my.security.secureBoot.enable = true`
on darwin reports

```
error: The option `my.security' does not exist. Definition values: …
```

No `isDarwin` / `isLinux` predicate takes part in that decision, and there is
deliberately no "this option is darwin-only" stub module: declaring an option in order to attach a friendlier
message makes the option *exist*, and an `apply = _: throw …` fires only when something reads it — which on the
wrong platform nothing does (see the note in `platforms/linux.nix`).

What this means when writing modules:

- A file imported only by `darwin.nix` cannot run on Linux, so it needs no platform guard.
- When one part of a module is platform-specific, move that part into a sibling file (`<app>/linux.nix`,
  `<domain>/darwin.nix`) instead of scattering `mkIf isLinux` through a shared one.
- `pkgs.stdenv.hostPlatform.is*` is for a *behaviour* difference inside a module that genuinely runs on both —
  `my/users/apps/browsers/brave` picking a wrapped or an unwrapped package — never for whether an option exists.
- `tests/user-option-reach.nix` enumerates both option trees and fails when reach changes. An option that is
  one-sided by design is recorded there with its reason.

### Module files

```
my/category/item/
├── options.nix    # type definitions (mkOption, mkEnableOption, submodules)
├── default.nix    # implementation (mkIf, mkMerge)
└── mynixos.nix    # opinionated defaults (mkDefault)
```

The role is carried by the filename, and platform variants keep the role in the name: `mynixos-darwin.nix` is a
defaults injector that only `darwin.nix` loads, while `my/users/users/darwin.nix` sits beside `default.nix` and
is therefore an implementation. An injector is never named plain `<platform>.nix` — that reads as an
implementation.

Option modules come in two shapes:

- A fragment returning `{ <domain> = lib.mkOption …; }`, loaded through the `mkOptionsModule` helper defined in
  each platforms file, which wraps it as `options.my.<domain>`.
- A plain module declaring `options.my.users` or `options.my.secrets` directly, imported without the wrapper
  (`my/users/apps/security/1password/options.nix`, `my/secrets/options.nix`).

Option modules must not capture `pkgs`. Naming it forces `_module.args.pkgs`, which depends on
`config.nixpkgs`, and hardware modules set `nixpkgs.hostPlatform` — the result is infinite recursion.
Declarations are built from `lib` alone.

### `my.*` namespace

Declared on both platforms:

- **`my.system`** — hostname, `flakeDir`, `allowedUnfreePackages`, the portable CLI package set
  (`my/system/base-packages`), helper scripts
- **`my.users`** — per-user configuration: the feature switches (`graphical`, `dev`, `terminal`, `ai`),
  `environment`, `input`, `theming`, `github`, `yubikeys`, and the `apps.*` tree
- **`my.hardware`** — the cross-platform core in `my/hardware/options.nix` (`cpu` / `gpu` metadata, and
  `audio`) plus the per-vendor categories each platform can act on
- **`my.dev`** — development tooling and `dev.containers`, whose `backend` enum defaults to **podman** on Linux
  (rootless, daemonless, no root-equivalent group) and to docker on darwin, where Colima is what runs. A
  `DOCKER_HOST` pointing at the rootless socket is what keeps `docker`-shaped tooling working
- **`my.fonts`** — `fonts.packages`, installed system-wide
- **`my.network`** — declared on both, but `sshFirewall` is the only key darwin has
- **`my.secrets`** — sops-nix wiring. Secrets must be **runtime paths**: `allowSecretsInStore` defaults to
  false and asserts on both `defaultSopsFile` and every `sops.secrets.<name>.sopsFile`, because `/nix/store` is
  world-readable and permanent. The shape it exists to block is `"${someFlakeInput}/secrets.yaml"`, which reads
  as one file and copies the whole *directory* it sits in

Linux only: `my.ai`, `my.boot`, `my.environment`, `my.filesystem`, `my.forensics`, `my.graphical`, `my.infra`,
`my.performance`, `my.presets`, `my.security`, `my.storage`, `my.streaming`, `my.theming`, `my.video` — plus
`my.hardware.{bluetooth,cooling,laptops.lenovo,memory,motherboards,peripherals,securityKeys,storage,usb}`,
`my.network.{openssh,tailscale,headscale,tor,monitoring,ipv6,unifi}` and
`my.system.{architecture,dualBoot,kernel,persistence,systemd,udev}`.

darwin only: `my.homebrew`, `my.nixGc` — plus `my.hardware.{biometrics,laptops.apple}` and
`my.network.sshFirewall`.

Two placements worth knowing because they are easy to guess wrong: hardware security keys are
`my.hardware.securityKeys.yubico` (pcscd, udev, PAM, gnupg agent), not part of `my.security`, which owns policy
— secure boot, TPM setup, audit rules — and only observes the devices. Theming is `my.theming`, and vogix is
the theme system; vogix is Linux/Hyprland, so the top-level domain is Linux-only while the per-user
`my.users.<name>.theming` submodule is declared on both.

`tests/user-option-reach.nix` is the enforced version of the three lists above, one line of reasoning per entry.

### System assembly (`lib/mkSystem.nix`)

One builder for both platforms. There is deliberately no `mkDarwinSystem`: a host should read the same way
whichever OS it runs, and a single entry point is what lets darwin-invalid arguments be rejected rather than
silently ignored.

```nix
mkSystem {
  platform     = "darwin";   # or "linux" (the default), or "oci"
  hostname     = "…";        # or set my.system.hostname
  hardware     = [ … ];      # module paths, e.g. mynixos.lib.hardware.laptops.apple.macbook-pro-m5-max
  users        = [ … ];
  config       = null;       # optional host module
  extraModules = [ ];
  my           = { … };      # or a LIST of layers
}
```

On `linux` and `darwin` there is no `system` argument: the hardware profile sets `nixpkgs.hostPlatform`.
`platform` selects the evaluator (`lib.nixosSystem` or `nix-darwin.lib.darwinSystem`), and the darwin branch
asserts that the resolved `hostPlatform` really is darwin, so a host that forgot to enable a hardware profile
fails loudly instead of building something subtly wrong.

**`platform = "oci"` emits a role as a container image.** The enum is flat even though it now carries two
axes — `linux`/`darwin` are operating systems, `oci` is an output *format*, and `vm` will be another. A
container is implicitly Linux, so it stays unambiguous, and one word in a host file reads better than a second
argument. `system` is **required** here and rejected on the other two, because a container has no hardware
profile to derive an architecture from.

A role is a machine, not a service: it gets its own tailnet node and its own identity, and knows nothing about
the host that runs it. That is what the oci branch's rejections enforce, each with a reason in the error —
`my.filesystem` (the image *is* the filesystem), `my.storage.impermanence` (a container's root is already
discarded; state is a bind mount the host declares), `hardware`, `users`, and `my.users` entries **carrying a
`fullName`**. The last is subtle: `lib/active-users.nix` filters on exactly `fullName`, so such an entry reaches
the same account and home-manager modules the `users` argument does and would pull a workstation closure into
the image. An entry *without* one is fine — it carries settings and creates no account.

`roles/` holds the role definitions (currently `roles/radicle/{default,builder,seed,identity}.nix`). A role is
a **function** a consumer instantiates with its own keys; `packages.*` builds a *reference* fleet whose
identities have no surviving private halves, tagged `reference` rather than `latest` so an image built for
nobody cannot be mistaken for a deployment. `my/system/oci-image` turns the resulting system into
`system.build.image` via `dockerTools.streamLayeredImage`.

Both branches assemble, in order: hardware modules → the platform module (`self.nixosModules.default` /
`self.darwinModules.default`) → the optional `config` module → the hostname → the per-user system modules →
home-manager → sops-nix → the `my` layers → `extraModules`. The NixOS branch additionally inserts disko or
plain-NixOS filesystem modules driven by `my.filesystem`; the darwin branch rejects `my.filesystem` with a
reason, since macOS owns the disk.

home-manager wiring is identical on both platforms (`lib/mk-system-core.nix`) — which is why one per-user app
module, writing only `home-manager.users.<name>.*`, serves both. `useUserPackages` is on;
`useGlobalPkgs` is deliberately off, because it would replace home-manager's `pkgs` and break the per-user
`my.system.allowedUnfreePackages` propagation.

**`my` as layers.** `my` may be a list. Each element becomes its own module, so the module system merges them:
`listOf` options concatenate, and two different values for one scalar are a hard error rather than a silent
last-wins. That is what lets a host contribute its own facts without re-splicing a shared user profile by hand.

**Per-user platform tiers.** Inside a `my.users.<name>` entry, `linux` and `darwin` are reserved keys holding
values that apply on that platform alone. `lib/mk-system-core.nix` collapses them before any module evaluates,
so `my.users.<name>.darwin` is never an option path. A misspelt tier is not stripped — it lands in the shared
layer and fails as an unknown option, which is the wanted behaviour.

**Users list.** Every entry needs `name` and `homeManager`. NixOS additionally requires `nixosUser`; on darwin
an entry may supply an optional `darwinUser`, and the account itself is driven from `my.users` through
`my/users/users/darwin.nix`.

### Key library functions (`lib/`)

- **`mkSystem`** — above.
- **`mkInstallerISO`** (`lib/mkInstallerISO.nix`) — installer image builder.
- **`mkApp`** (`lib/mk-app.nix`) — builds a per-user app module from a `path` under `userCfg.apps` and a `home`
  function, collapsing the repeated `home-manager.users = mapAttrs … mkIf … (activeUsers …)` boilerplate.
  Optional `option` makes the module declare its own option; optional `unfree` adds package names to
  `my.system.allowedUnfreePackages` when any user enables the app. App modules import this file by relative
  path and call it with their own module args — it is deliberately *not* delivered through `_module.args`,
  because an app module's return value *is* `mkApp args {…}`, so routing it that way forces mkApp at
  module-structure time and recurses through `config → imports → config`.
- **`activeUsers`** (`lib/active-users.nix`) — the users that have a `fullName`. Exported in `lib` and
  delivered to every module as the `activeUsers` `_module.arg` from `platforms/common.nix`, which is safe
  because it is only forced lazily inside config bodies.
- **`mkAppOption`**, **`floatBetween`** (`lib/app-options.nix`) — the structured app option, whose submodule
  carries `enable`, `persisted`, `persistedDirectories`, `persistedFiles` plus anything passed as
  `extraOptions`; and a float type constrained to a range.
- **`lib.hardware`** — hardware profile paths, for consumers to put in `mkSystem`'s `hardware` list.
- **`lib.securityKeys`** — `yubikey` / `solokey` / `nitrokey` value constructors.

### Key design patterns

**App configuration.** Apps are per-user at `my.users.<name>.apps.<category>.<group>.<app>` — e.g.
`apps.graphical.terminals.alacritty`, `apps.ai.tools.claude-code`, `apps.security.passwords.onePassword`. Apps
that are *selected* rather than switched on — the browser through `environment.BROWSER`, the multiplexer
through `terminal.multiplexer` — deliberately have no `apps.*` option, so there is exactly one way to say the
thing.

**Persistence aggregation (Linux).** An app declares `persistedDirectories` / `persistedFiles` on its own
`apps.*` option. `my/storage/impermanence/aggregation.nix` walks every user's app tree and computes
`my.system.persistence.aggregated` from the apps that are both enabled and persisted; that option is
`readOnly` at every level, so nothing else may contribute to it. Everything with no `apps.*` option to carry
the paths — selector-driven apps, system-level modules — writes `my.system.persistence.features` instead, and
`my/storage/impermanence/impermanence.nix` turns both into `environment.persistence`. `my.system.persistence`
is declared only on Linux, so a cross-platform module contributes from a Linux-only sibling
(`<app>/linux.nix`, `my/secrets/linux.nix`) rather than writing an option that does not exist on darwin.

**User management.** A user becomes a real account only when it has a `fullName`; an entry without one
carries mounts, security keys and email but creates no account.

**Hardware profiles.** Exported as `mynixos.lib.hardware.*`. A model profile flips the generic `my.hardware.*`
category options, which pull in the vendor implementations, and sets `nixpkgs.hostPlatform` — which is what
gives a host its architecture on both platforms.

## Adding a New App Module

1. Create `my/users/apps/<category>/<app>/default.nix` as a `mkApp` module that carries its own option:

   ```nix
   args:

   # relative depth depends on where the module sits
   (import ../../../../../lib/mk-app.nix).mkApp args {
     path = "graphical.terminals.alacritty";   # option path under userCfg.apps
     option = {
       name = "alacritty";
       default = false;
       description = "Alacritty terminal";
       persistedDirectories = [ ];
     };
     home = _: { programs.alacritty.enable = true; };
   }
   ```

   `path` is the option path, not the directory path; the two need not match. Declaration and implementation
   living in one file is what makes reach enforceable and a path typo unrepresentable.

2. Import the module from the `platforms/*.nix` whose reach it should have: `common.nix` for both platforms,
   `linux.nix` or `darwin.nix` for one.

3. If the app is not a `mkApp` module (selector-driven, system-level, always-on), or has one implementation per
   platform, declare the option in a sibling `options.nix` and import that from the platforms file both
   implementations can see — `my/users/apps/security/1password` is the worked example, with `default.nix` for
   Linux, `darwin.nix` for macOS and a common `options.nix`.

4. An app with an `apps.*` option declares its persistence there, through `persistedDirectories` /
   `persistedFiles`. A selector-driven app has no such option, so its persistence is a fleet-wide write to
   `my.system.persistence.features` — Linux-only, and therefore in `<app>/linux.nix`, imported by
   `platforms/linux.nix`.

5. If the app exists on one platform only, record its option prefix and the reason in
   `tests/user-option-reach.nix`.

## Adding a New Domain

1. Create `my/<domain>/` with `options.nix` and `default.nix` (plus `mynixos.nix` if it ships defaults).
2. Load the options through `mkOptionsModule` and the implementation directory from `platforms/common.nix`,
   `linux.nix` or `darwin.nix` — whichever matches where the implementation can actually work.
3. Implement with `mkIf config.my.<domain>.*`.
4. If the domain is one-sided, record it in `tests/user-option-reach.nix`.

## Tests

- `tests/module-eval.nix` — evaluates NixOS systems and forces the four places module config lands: system
  packages, the per-user home-manager package sets, systemd unit names, created accounts.
- `tests/type-validation.nix` — bad values must fail type checking. Each accessor is first run against a valid
  config, so "the option does not exist" cannot masquerade as a pass.
- `tests/integration-smoke.nix` — realistic configurations evaluate.
- `tests/persistence-and-edge-cases.nix` — persistence aggregation, partial users, display manager types,
  network defense.
- `tests/real-system-pkgs.nix` — evaluates a system the `mkSystem` way, with `pkgs` *not* in `specialArgs`, so
  mkApp's pkgs sourcing is genuinely exercised.
- `tests/user-option-reach.nix` — which `my.*` options each platform declares.
- `tests/mksystem.nix` — platform dispatch, argument rejection, `my` layering, the per-user platform tiers.
- `tests/darwin-smoke.nix` — the darwin module set, evaluated from a Linux runner.
- `tests/secrets-store-policy.nix` — sops files must not be store paths. Every case is paired with its
  opposite, because a policy that only ever says "no" is indistinguishable from an assertion that never fires.

Under the `tests` output rather than `checks`, so `nix flake check` stays light and KVM-free — run on demand
with `nix build .#tests.<system>.<name> -L`, and part of the pre-push routine:

- `tests/vm-system.nix` — boots a real qemu VM and asserts runtime behaviour.
- `tests/vm-login.nix` — SDDM under the vogix greeter, end to end: the greeter renders (OCR on its hostname
  line), the palette really reaches `theme.conf`, and typed credentials authenticate through PAM.
- `tests/vm-radicle.nix` — two VMs on an isolated LAN, which is what makes "private network" true by
  construction rather than by configuration: seed, CI broker firing on a fetch, and a workstation profile
  pushing to it.

`tests/module-eval.nix` deliberately stops short of `system.build.toplevel`: vogix uses
import-from-derivation, so building the toplevel needs an `x86_64-linux` builder at evaluation time, and
forcing it buys no extra coverage of mynixos itself. `tests/darwin-smoke.nix` reads only `config` for the
parallel reason — a darwin toplevel would need an aarch64-darwin builder, and it runs on a Linux runner. The
smoke suites (`tests/integration-smoke.nix`, `tests/persistence-and-edge-cases.nix`) do force it, on the Linux
systems `checks` is declared for.

## Important Constraints

### Single Commit Convention

When working on a feature branch, maintain a single commit. Use `git commit --amend` to update the commit
rather than creating new ones.

### No Generated Signatures

Do NOT add "Generated with Claude Code" or similar text to files, commits, PRs, or comments.

### Opinionated Defaults Pattern

Defaults go in a `mynixos.nix` injector and use `mkDefault`, so a user always wins:

```nix
# my/users/terminal/mynixos.nix
apps.terminal.viewers.bat.enable = lib.mkDefault true;
```

Options that are simply off until asked for use `mkEnableOption`:

```nix
nopasswdRebuild = lib.mkEnableOption "NOPASSWD sudo for nixos-rebuild (skips YubiKey touch on rebuild)";
```

## Code Style

- Use `cfg` for `config.my.<namespace>`.
- Implementation modules commonly open with `with lib;`; option modules qualify `lib.` and take `lib` alone.
- Prefer `mkIf` over explicit conditionals; use `mkMerge` when combining several config blocks.
- Keep implementations in `my/`, not in `flake.nix`.
- Nothing is discovered by scanning the filesystem: a `platforms/*.nix` is always the entry point, and the few
  modules that pull in siblings name them in their own `imports`.
- statix and deadnix run in CI. App modules are bare `args:` lambdas on purpose: naming an unused `pkgs` would
  trip deadnix, and mkApp sources `pkgs` from config instead.

## External Dependencies

- `nixpkgs` (nixos-unstable), `disko`, `impermanence`
- `home-manager` (fork: `i-am-logger/home-manager`, ref `feature/webapps-module`)
- `vogix`, `hypr-vogix` — theming
- `lanzaboote` — secure boot; `sops-nix` — secrets
- `nix-darwin`, `nix-homebrew` — macOS. nix-darwin follows this repo's `nixpkgs`, because the two must agree on
  nixos-render-docs' CLI for the darwin-manual build. nix-homebrew is what installs Homebrew at all;
  nix-darwin's own `homebrew.*` module only writes a Brewfile and runs `brew bundle`.
- `treefmt-nix`, `git-hooks` — tooling

## Further Reading

- `docs/CONTRIBUTING.md`
- `docs/network-defense.md`
- `docs/radicle.md` — the forge as it runs on a host today
- `docs/radicle-containers.md` — roles as machines: the `platform = "oci"` emitter, what a role may not
  declare, and why the seed is added-then-retired rather than migrated
- `docs/SECURE_BOOT_SETUP.md`
- `docs/yubikey-on-darwin.md` — what YubiKey support on macOS would take, and why this fleet does not carry it
