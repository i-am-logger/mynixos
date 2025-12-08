# Custom Home-Manager Modules

This directory contains custom home-manager modules for programs/services not yet available in upstream home-manager.

## Structure (Mirrors Upstream)

```
modules/
├── programs/     # Custom program modules (e.g., programs/someapp.nix)
├── services/     # Custom service modules (e.g., services/someservice.nix)
└── README.md
```

This structure **exactly mirrors** upstream home-manager:
```
home-manager/modules/
├── programs/
├── services/
└── ...
```

## Why Match Upstream Structure?

1. **Easy PR Preparation** - Copy module directly to upstream repo
2. **Familiar API** - Same structure as existing home-manager modules
3. **Import Compatibility** - Can import entire directory or individual files

## Current Status

✅ **opencode** - Already exists in upstream home-manager (no custom module needed)
   - See: `home-manager/modules/programs/opencode.nix`
   - Full-featured with settings, rules, commands, agents, themes, MCP integration

## Integration

Custom modules are automatically injected via `lib/mkSystem.nix`:

```nix
home-manager.sharedModules = [
  # Example: if we had a custom module
  # ../modules/programs/customapp.nix
];
```

## Adding New Custom Modules

**Before creating a custom module**, check if it exists upstream:
```bash
ls ~/Code/github/tmp/home-manager/modules/programs/{app}.nix
```

If it doesn't exist upstream:

1. **Create module**: `modules/programs/{app}.nix` or `modules/services/{service}.nix`
2. **Follow upstream patterns**: See `~/Code/github/tmp/home-manager/modules/programs/`
3. **Add to sharedModules**: Update `lib/mkSystem.nix`
4. **Use in mynixos**: Update `my/users/apps/` to use `programs.{app}.enable`

## Module Template

```nix
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkOption mkEnableOption types;
  cfg = config.programs.{app};
in
{
  meta.maintainers = [ ];

  options.programs.{app} = {
    enable = mkEnableOption "{app}";
    package = mkOption {
      type = types.package;
      default = pkgs.{app};
      description = "The {app} package to use.";
    };
    # ... more options
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];
    # ... more config
  };
}
```

## Contributing Upstream

When a custom module is mature:

1. Fork `nix-community/home-manager`
2. Copy module to `home-manager/modules/programs/` or `services/`
3. Test with home-manager test suite
4. Submit PR following [contribution guidelines](https://github.com/nix-community/home-manager/blob/master/CONTRIBUTING.md)
5. Once merged upstream, remove from mynixos and update flake input

## Example: Real Upstream Modules

- **opencode** - Full-featured with config, rules, commands, agents, themes, MCP
- **vscode** - Complex module with extensions, keybindings, settings
- **firefox** - Multi-profile support with policies and extensions

Browse upstream for patterns: `~/Code/github/tmp/home-manager/modules/programs/`
