# AGENTS.md

Quick reference for AI coding agents working in this repository.

## Build/Lint/Test Commands

```bash
nix flake check                              # Everything under `checks`
nix fmt                                      # treefmt: nixpkgs-fmt, shfmt, shellcheck, yamlfmt
nix run nixpkgs#statix -- check .            # Anti-pattern lint
nix run nixpkgs#deadnix -- --fail .          # Dead-code lint
nix build .#checks.x86_64-linux.<name> -L    # A single check
nix build .#tests.x86_64-linux.vm-system -L  # Booting VM test, kept out of `checks`
bash scripts/module-coverage.sh              # Which my/ modules platforms/ imports
```

`checks` is defined for `x86_64-linux` and `aarch64-linux` only, because most of
`tests/` builds a real `lib.nixosSystem`. `formatter`, `devShells` and `apps` add
`aarch64-darwin`, so `nix fmt` and `nix develop` work on a Mac. CI runs
`nix flake check`, statix, deadnix and the coverage script on pull requests and
on pushes to `master`.

There is no `packages` output.

From a Mac, exercise a change against a real host by evaluating (not building)
the consumer flake with this checkout substituted in. Run from the consumer
checkout:

```bash
nix eval --override-input mynixos ~/Code/mynixos \
  '.#nixosConfigurations.yoga.config.networking.hostName'
nix eval --override-input mynixos ~/Code/mynixos \
  '.#darwinConfigurations."aether5d-dev".config.my.homebrew.enable'
```

## Architecture

- `platforms/{common,linux,darwin}.nix` compose the module set.
  `nixosModules.default` imports `platforms/linux.nix`; `darwinModules.default`
  imports `platforms/darwin.nix`. Beyond those two, `flake.nix` names only the
  hardware profile paths it exports as `lib.hardware` and the flake input
  *values* (impermanence, lanzaboote, nix-homebrew) that cannot be path
  imports.
- Platform reach is structural. An option is declared in the file that
  implements it, and the `platforms/*.nix` which imports that file decides where
  the option exists. Setting a Linux-only option on a darwin host is
  `The option ... does not exist`, not a silent no-op — so reach needs no
  `isLinux`/`isDarwin` guard.
- One `mkSystem` (`lib/mkSystem.nix`) builds both platforms, selected by
  `platform ? "linux"`. It takes no `system` argument: the hardware profile sets
  `nixpkgs.hostPlatform`, and the darwin branch asserts the two agree.
- Apps are per-user, at `my.users.<name>.apps.<...>`. A `mkApp` module declares
  its own option through the spec's `option` field, so declaration and
  implementation share one file and one `path` string (`lib/mk-app.nix`).

## Code Style

- **Imports**: `with lib;` at the top of implementation modules; options modules
  stay explicit (`lib.mkOption`, `lib.types.*`)
- **Conditionals**: prefer `mkIf` over explicit conditionals; use `mkMerge` for
  merging multiple attribute sets
- **Types**: type options in `my/category/item/options.nix` co-located with the
  implementation, or in a `mkApp` spec's `option` field
- **Variables**: use descriptive names (`cfg` for `config.my.<namespace>`)
- **Defaults**: use `mkDefault` for opinionated defaults users can override
- **Module pattern**: `config = mkMerge [ ... ]` with separate config blocks per
  concern
- **Structure**: `my/category/item/{options.nix, default.nix, mynixos.nix}`. A
  platform-specific variant of a role keeps the role in its name —
  `options-linux.nix`, `mynixos-darwin.nix` — so an injector never reads as an
  implementation
- **No `pkgs` in an options module**: naming it forces `_module.args.pkgs` ->
  `config.nixpkgs`, which recurses against hardware modules that set
  `nixpkgs.hostPlatform`
- **`mkApp` is imported by relative path**, not taken from `_module.args`: an app
  module's return value *is* `mkApp args { ... }`, so routing it through module
  args forces it at module-structure time and recurses
- **Error handling**: the type system enforces validity at evaluation time

## Important Constraints

- **Single commit per feature branch**: keep one commit and use
  `git commit --amend` to update it (matches `CLAUDE.md`; avoids dirty fix-up
  commits)
- **No signatures**: never add "Generated with Claude Code" or similar to files,
  commits, or PRs
- **Separation**: mynixos provides types, options and implementations; the
  consumer flake (`i-am-logger/flake`) provides data, one directory per host
  under `systems/`
- **No auto-imports**: nothing is discovered by scanning directories.
  `platforms/*.nix` names each module tree's entry point explicitly; a module
  that pulls in siblings (`my/theming`, the hardware profiles,
  `my/hardware/security-keys/yubico`) does so through its own explicit
  `imports` list
