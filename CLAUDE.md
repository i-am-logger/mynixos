# CLAUDE.md

mynixos: a typed `my.*` NixOS/nix-darwin module library, built from one entry point. The host flake
(github.com/i-am-logger/flake) supplies the data: hosts, users, secrets.

**Rules: read `docs/nix-rules.md` first.** It holds the must-follow rules (platform reach, file roles,
option modules without `pkgs`, generic only, red first). Below are only mynixos's deltas. This file's
size is pinned in `docs/claude-md-budget` (at most 4096): it only shrinks, and a raise is its own commit.
Checked by `checks.instructions-size`.

## Commands

- `nix fmt`; `nix flake check` (light, no KVM; covers treefmt, statix and deadnix via `checks.pre-commit`).
- VM tests on demand: `nix build .#tests.x86_64-linux.<vm-system|vm-login|vm-radicle> -L`.
- `checks`/`tests` exist for x86_64-linux and aarch64-linux only; the Mac has `nix fmt` and `nix develop`.

## Gate and releases (until cops)

- One shared checkout, used by several sessions: commit with a pathspec (`git commit -- <paths>`), never the
  whole index, no worktrees or clones.
- `.git/hooks/pre-push` builds `packages/*` (scripts/build-packages.sh), evaluates the 4 real hosts
  (flake/scripts/check-hosts.sh) and builds ads-dev1's toplevel. Eval tests don't prove a host builds.
- Releases: the release-please PR, merged once master CI is green; tags `mynixos-vX.Y.Z`. Both go when the
  repo moves to cops (docs/nix-rules.md rule 17).

## Assembly (lib/mkSystem.nix)

- One builder, no `mkDarwinSystem`. `platform` is the OS (`linux`, `darwin`) and nothing else: a format is
  an output (`system.build.image` via `extendModules` onto platforms/oci-variant.nix, like `system.build.vm`).
- The variant overrides what a container shouldn't run; it never refuses a configuration.
- `platforms/{common,linux,darwin}.nix` is the module list; flake.nix names only input values.
- `my` may be a list of layers: lists concatenate, and two different scalars are an error.
- `my.users.<name>.{linux,darwin}` are platform tiers, collapsed before evaluation; a misspelt tier fails
  as an unknown option.
- home-manager wiring is shared (lib/mk-system-core.nix); `useGlobalPkgs` stays off, or the per-user
  unfree list breaks.

## Library

- `mkApp` (lib/mk-app.nix): a per-user app from a `path` under `apps` and a `home` function; app modules
  import it by relative path. It isn't delivered via `_module.args`, which recurses.
- `activeUsers`: users with a `fullName`, the only ones that become accounts.
- `mkAppOption` carries `enable`, `persisted`, `persistedDirectories`, `persistedFiles`.

## State

- Persistence (Linux): an app declares `persistedDirectories`/`persistedFiles` on its own option.
  Everything else writes `my.system.persistence.features`, from a Linux-only sibling file.
- Secrets are runtime paths, never store paths (tests/secrets-store-policy.nix).

## Where things are

- The namespace reach is `tests/user-option-reach.nix`; each test file's header says what it covers.
- Hardware profiles are `lib.hardware.*`: a model profile sets `nixpkgs.hostPlatform`.
- Security keys live in `my.hardware.securityKeys`, policy in `my.security`; theming is `my.theming`.
- No AI attribution in commits.
