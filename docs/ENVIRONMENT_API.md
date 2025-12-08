# Environment API & TOML Conversion Patterns

## Overview
mynixos provides a typed API for managing environment variables and preferred applications with opinionated defaults.

## Environment Variables API

### Usage

```nix
my.users.logger = {
  environment = {
    BROWSER = pkgs.brave;          # Sets BROWSER env var
    TERMINAL = pkgs.wezterm;       # Sets TERMINAL env var  
    EDITOR = pkgs.helix;           # Sets EDITOR and VISUAL env vars
    PAGER = pkgs.bat;              # Sets PAGER env var
    VIEWER = pkgs.bat;             # Sets VIEWER env var
    SHELL = pkgs.bashInteractive;  # Sets SHELL env var
    FILE_MANAGER = pkgs.yazi;      # Sets FILE_MANAGER env var
  };
};
```

### Package Coercion

The API supports two forms:

```nix
# Simple form (coerced to full form)
environment.PAGER = pkgs.bat;

# Full form (with custom settings)
environment.PAGER = {
  package = pkgs.bat;
  settings = {
    theme = "TwoDark";
    paging = "always";
  };
  enable = true;  # defaults to true
};
```

### Opinionated Defaults

When `graphical.enable = true`, these defaults apply:

| Variable | Default | Description |
|----------|---------|-------------|
| BROWSER | brave | Web browser |
| TERMINAL | wezterm | Terminal emulator |
| EDITOR | helix | Text editor (also sets VISUAL) |
| PAGER | bat | Pager for viewing text |
| VIEWER | bat | File viewer |
| SHELL | bash | Shell |
| FILE_MANAGER | yazi | File manager |

### Binary Extraction

The system automatically extracts the correct binary from packages:

```nix
environment.PAGER = pkgs.bat;
# Results in: PAGER=/nix/store/.../bin/bat

environment.EDITOR = pkgs.helix;
# Results in: EDITOR=/nix/store/.../bin/hx
```

## TOML Conversion Pattern

### Problem

`builtins.fromTOML` collapses multiline strings, breaking configurations that depend on exact formatting (like starship prompts).

**Example**:
```toml
# Original TOML
format = """\
$shell $nix_shell\
$fill\ 
$direnv$pulumi\
"""

# After builtins.fromTOML
format = "$shell $nix_shell$fill$direnv$pulumi"  # Line breaks lost!
```

### Solution: Hybrid Approach

Load TOML for structure, override problematic multiline strings manually:

```nix
let
  settings = (builtins.fromTOML (builtins.readFile ./config.toml)) // {
    # Override format string with correct multiline
    format = ''
      $shell $nix_shell$fill\ 
      $direnv$pulumi$rust$nim$c$nodejs$golang\
      $line_break\
      $git_branch $git_commit $git_status $git_state\
      $fill\
      $username$hostname $battery \
      $line_break\
      $directory\
      $fill\
      $line_break\
      $sudo$character \
    '';
  };
in {
  programs.starship.settings = settings;
}
```

### Rationale

- ✅ Preserves TOML for simple key-values (type safety)
- ✅ Overrides problematic multiline strings (correctness)
- ✅ Easy to maintain (edit TOML, override only what breaks)
- ✅ Best of both worlds: structure from TOML, precision where needed

### When to Use

Use this pattern when:
1. You have a large TOML config (>100 lines)
2. Contains multiline strings with significant whitespace
3. Manual conversion would be tedious and error-prone

### Example: Starship

See `my/users/apps/prompts/starship.nix` for a complete implementation.

## Category-Based Enabling

Apps use category-based enabling with opinionated defaults:

```nix
# All apps default to enabled
my.users.logger.apps.shells.bash.enable;  # true by default

# Category feature flags enable all apps in category
my.users.logger.dev.enable = true;  # Enables all dev.* apps
```

Implementation uses `appHelpers.shouldEnable`:

```nix
{ config, lib, pkgs, appHelpers, ... }:

{
  config = {
    home-manager.users = lib.mapAttrs
      (name: userCfg:
        lib.mkIf (appHelpers.shouldEnable userCfg "shells" "bash") {
          programs.bash.enable = true;
        })
      config.my.users;
  };
}
```

This checks:
1. Explicit app enable: `userCfg.apps.shells.bash.enable` (defaults to true)
2. Category feature: `userCfg.shells.enable` (if set, overrides app default)

## Implementation Details

### environment.nix Structure

Options defined in: `options/users/environment.nix`
- Defines all environment variable options
- Sets opinionated defaults when `graphical.enable = true`
- Uses package coercion for flexible API

Implementation in: `my/users/environment-defaults.nix`
- Extracts packages from environment options
- Sets `home.sessionVariables.*` with binary paths
- Configures XDG MIME defaults for graphical apps

### App Module Pattern

All app modules follow this structure:

```nix
{ config, lib, pkgs, appHelpers, ... }:

{
  config = {
    home-manager.users = lib.mapAttrs
      (name: userCfg:
        lib.mkIf (appHelpers.shouldEnable userCfg "category" "app") {
          # home-manager configuration
        })
      config.my.users;
  };
}
```

Key points:
- Use `appHelpers.shouldEnable` for category-based enabling
- Wrap in `home-manager.users = mapAttrs` pattern
- Access user config via `userCfg` parameter

## Examples

### Override PAGER to less

```nix
my.users.logger = {
  environment.PAGER = pkgs.less;
};
```

### Disable an app

```nix
my.users.logger = {
  apps.shells.fish.enable = false;  # Disable fish
};
```

### Enable entire category

```nix
my.users.logger = {
  dev.enable = true;  # Enables all dev.* apps
};
```

### Custom bat settings via environment API

```nix
my.users.logger = {
  environment.PAGER = {
    package = pkgs.bat;
    settings = {
      theme = "gruvbox-dark";
      paging = "always";
    };
  };
};
```

## See Also

- `options/users/environment.nix` - Environment variable options
- `my/users/environment-defaults.nix` - Binary extraction implementation  
- `my/users/apps/prompts/starship.nix` - TOML hybrid pattern example
- `lib/app-helpers.nix` - Category-based enabling logic
