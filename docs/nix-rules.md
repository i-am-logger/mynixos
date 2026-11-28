# Nix rules

The must-follow architecture rules for mynixos and the Nix repos built on it. Each repo's CLAUDE.md points
here and adds only its own deltas. Each rule names its source, a file in this repository or a decision
number; a rule without one doesn't belong here.

## Structure
1. **Platform reach is structural.** An option is declared in the file that implements it, and the
   `platforms/*.nix` that imports that file decides where the option exists. No `isDarwin`/`isLinux` test
   decides whether an option exists, and there are no stub "darwin-only" modules
   (`tests/user-option-reach.nix`).
2. **Platform-specific parts go in sibling files** (`<app>/linux.nix`, `<domain>/darwin.nix`), not
   `mkIf isLinux` scattered through a shared file. `stdenv.hostPlatform.is*` is only for a behaviour
   difference in a module that runs on both (`my/users/apps/browsers/brave/`).
3. **File roles:** `options.nix` declares, `default.nix` implements, and `mynixos.nix` injects opinionated
   defaults with `mkDefault`, so the user always wins. Off-until-asked options use `mkEnableOption`
   (`platforms/linux.nix`, `platforms/darwin.nix`).
4. **Option modules never take `pkgs`**: declarations come from `lib` alone. Naming `pkgs` forces
   `_module.args.pkgs`, which depends on `nixpkgs.hostPlatform`, which hardware modules set: infinite
   recursion (`lib/mk-app.nix`, `tests/real-system-pkgs.nix`).
5. **One way to say a thing.** Apps that are selected rather than switched on (the browser via
   `environment.BROWSER`, the multiplexer via `terminal.multiplexer`) get no `apps.*` option. Apps are
   per-user, `my.users.<name>.apps.<category>.<group>.<app>`, never a top-level `my.apps`
   (`tests/user-option-reach.nix`).
6. **Nothing is discovered by scanning the filesystem.** `platforms/*.nix` is the entry point, and a
   module names its siblings in its own `imports` (`platforms/common.nix`).
7. **mynixos stays generic:** no account names, hostnames or a particular machine's hardware. Names and
   personal data belong to the consuming flake, which passes them in as option values. For example
   `apps.ai.tools.claude-code.accounts` takes a list of names (`my/users/apps/ai/claude-code/options.nix`).

## State and secrets (Linux)
8. **Home can be tmpfs, so only declared persistence survives a reboot.** An app declares
   `persistedDirectories`/`persistedFiles` on its own `apps.*` option. `my.system.persistence.aggregated`
   is readOnly, and anything without an `apps.*` option writes `my.system.persistence.features`. Never
   create state on tmpfs, and never persist a folder that a persisted parent already covers
   (`my/storage/impermanence/aggregation.nix`, `my/storage/impermanence/impermanence.nix`).
9. **Secrets are runtime paths, never store paths.** sops-nix decrypts at activation, and
   `allowSecretsInStore` defaults to false and asserts (`tests/secrets-store-policy.nix`).

## Inputs and composition
10. **Pin inputs by tag, never by branch.** Until a repo has release tags, pin a commit on its main line
    (`flake.nix`, the vogix input comment).
11. **One nixpkgs.** Consumers follow mynixos's: `nixpkgs.follows = "mynixos/nixpkgs"`.
12. **Override an input of an input with `follows`, never by forking.** For example,
    `mynixos.inputs.vogix.follows = "vogix"`.
13. **Users are data.** User definitions are plain attrsets with no `lib`. A host states only what
    differs, and `my` may be a list of layers, merged by each option's type (`tests/mksystem.nix`).

## Types and names
14. **Typed options, no stringly config** (decision 0189): every option has a domain type, `types.enum`,
    `types.strMatching`, a typed submodule or a named constant, never a raw string or number standing for
    a concept, in tests too. Generated configuration is rendered from typed values (`pkgs.formats.*`,
    `builtins.toJSON`) and never assembled by string concatenation (`tests/type-validation.nix`).
14a. **Event-driven units** (decision 0189): generated services wake on events (path, socket or D-Bus
    activation, inotify), not on polling timers. A timer is for work that is truly periodic, and says why.
15. **Names in full, by subject, not vendor**; no abbreviations (decision 0151).

## Tests and checks
16. **Red first.** A new option or behaviour lands with a module-eval or type test that failed before the
    change. A type test runs its accessor on a valid config first, so "the option does not exist" can't
    pass as a refusal. A policy test is paired with its opposite (`tests/type-validation.nix`,
    `tests/secrets-store-policy.nix`).
17. **Checks and releases go through cops** (releasable's [watch] under `devenv up`): no GitHub Actions,
    no release-please or release-plz, no pull requests. statix, deadnix and the formatter run as watch
    checks (decisions 0153, 0159).
18. **`nix flake check` stays light and needs no KVM.** VM tests sit under the `tests` output and are built
    on demand (`flake.nix`, `tests` output).

## Instruction files
- A repo's CLAUDE.md is a pointer here plus that repo's deltas, and sits exactly at its byte budget
  (at most 4096 bytes to start). The budget is in a committed file, so the file only shrinks, and a raise
  is a commit of its own that says why. This file is at most 12288 bytes (decision 0180).
- No instruction file names a path under a person's home folder. Workspace habits (sudo, rebuilds,
  where clones go) belong to the private flake's CLAUDE.md, not here.

## Changes
- 2026-11-28: rules 14 and 14a carry decision 0189 (typed options, no stringly config, event-driven units).
- 2026-11-28: first version. Sources are repo files or decision numbers only, so the file can live in a
  public repository.
