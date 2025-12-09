# AGENTS.md

Quick reference for AI coding agents working in this repository.

## Build/Lint/Test Commands

```bash
nix flake check                                              # Evaluate flake & check syntax
nixpkgs fmt                                                  # Format all Nix files
nix build /etc/nixos#checks.x86_64-linux.github-runner-test  # Run all 20 test suites (GitHub runner image)
nix build /etc/nixos#github-runner-image                     # Build runner image only
```

## Code Style

- **Imports**: Use `with lib;` at top of module files for common lib functions
- **Conditionals**: Prefer `mkIf` over explicit conditionals; use `mkMerge` for merging multiple attribute sets
- **Types**: Type all options in `my/category/item/options.nix` co-located with implementations
- **Variables**: Use descriptive names (`cfg` for `config.my.<namespace>`)
- **Defaults**: Use `mkDefault` for opinionated defaults users can override
- **Module pattern**: `config = mkMerge [ ... ]` with separate config blocks per feature
- **Error handling**: Type system enforces validity at evaluation time
- **Structure**: `my/category/item/{options.nix, default.nix, mynixos.nix}`

## Important Constraints

- **No amend commits**: Create new commits (don't use `git commit --amend`)
- **No signatures**: Never add "Generated with Claude Code" or similar to files, commits, or PRs
- **Separation**: mynixos provides types/options/implementations; user configs in `/etc/nixos/Systems/` provide data
- **No auto-imports**: All modules explicitly imported in flake.nix (no dynamic discovery)
