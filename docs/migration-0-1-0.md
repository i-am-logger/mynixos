# Migration Guide: mynixos 0.1.0 - API Refactoring

This guide explains the API changes in mynixos 0.1.0 and how to update your system configurations.

## Overview

mynixos has undergone a major refactoring to flatten the API namespace. The `my.features.*` namespace has been removed and replaced with direct top-level namespaces like `my.security`, `my.environment`, `my.performance`, and more.

This change makes the API flatter, more intuitive, and aligns system-level configuration with user-level configuration.

**Status**: This is a breaking change. All system configurations must be updated before upgrading to mynixos 0.1.0.

## API Changes

### System-Level Namespace Changes

| Old API | New API | Category |
|---------|---------|----------|
| `my.features.security` | `my.security` | Security configuration |
| `my.features.environment` | `my.environment` | Environment variables, locale, timezone |
| `my.features.performance` | `my.performance` | Performance tuning (zram, vmtouch) |
| `my.features.ai` | `my.ai` | Ollama AI infrastructure |
| `my.features.development.docker` | `my.infra.docker` | Docker container runtime |
| `my.features.development.k3s` | `my.infra.k3s` | Kubernetes cluster (K3s) |
| `my.features.development.github-runner` | `my.infra.github-runner` | GitHub Actions runner |
| `my.features.streaming.streamdeck` | `my.video.streamdeck` | StreamDeck hardware support |
| `my.features.streaming.v4l2loopback` | `my.video.virtual` | Virtual camera device |
| `my.features.graphical` | *auto-enabled by user* | Graphical environment |

### User-Level Namespace Changes

| Old API | New API | Description |
|---------|---------|-------------|
| `my.users.<name>.features.graphical` | `my.users.<name>.graphical` | Enable Hyprland + desktop |
| `my.users.<name>.features.dev` | `my.users.<name>.dev` | Enable development tools |
| `my.users.<name>.features.streaming` | `my.users.<name>.streaming` | Enable streaming stack |
| `my.users.<name>.features.ai` | `my.users.<name>.ai` | Enable MCP servers |
| `my.users.<name>.features.webapps` | `my.users.<name>.webapps` | Browser webapps |
| `my.users.<name>.features.hyprland` | `my.users.<name>.hyprland` | Hyprland keybinds + config |

## Migration Example

### Before (mynixos v0.0.x)

```nix
{ mynixos, ... }:

mynixos.lib.mkSystem {

  my = {
    # System configuration
    system = {
      enable = true;
      hostname = "myhost";
    };

    # Hardware (no change)
    hardware = {
      motherboards.gigabyte.x870e-aorus-elite-wifi7.enable = true;
    };

    # OLD: Features namespace
    features = {
      system.enable = true;
      environment.enable = true;
      security.enable = true;
      security.secureBoot.enable = true;
      security.yubikey.enable = true;
      performance.enable = true;
      ai.enable = true;
      ai.rocmGfxVersion = "11.0.2";
      development.docker.enable = true;
      development.k3s.enable = true;
      development.github-runner.enable = true;
      streaming.streamdeck.enable = true;
      graphical.enable = true;
      graphical.hyprland.defaultTerminal = "wezterm";
    };

    # User configuration (OLD)
    users.logger = {
      fullName = "My Name";
      email = "me@example.com";
      hashedPassword = "<hash>";

      features = {
        graphical = true;
        dev = true;
        streaming = true;
        ai = true;
        webapps.enable = true;
      };
    };
  };
}
```

### After (mynixos 0.1.0)

```nix
{ mynixos, ... }:

mynixos.lib.mkSystem {

  my = {
    # System configuration (no change)
    system = {
      enable = true;
      hostname = "myhost";
    };

    # Hardware (no change)
    hardware = {
      motherboards.gigabyte.x870e-aorus-elite-wifi7.enable = true;
    };

    # NEW: Flattened namespaces
    environment = {
      enable = true;
      xdg.enable = true;
      motd.enable = true;
    };

    security = {
      enable = true;
      secureBoot.enable = true;
      yubikey.enable = true;
    };

    performance = {
      enable = true;
      zramPercent = 15;
    };

    ai = {
      enable = true;
      rocmGfxVersion = "11.0.2";
    };

    infra = {
      docker.enable = true;
      k3s.enable = true;
      github-runner.enable = true;
    };

    video = {
      streamdeck.enable = true;
    };

    # User configuration (NEW flattened API)
    users.logger = {
      fullName = "My Name";
      email = "me@example.com";
      hashedPassword = "<hash>";

      # User-level features are now top-level booleans
      graphical = true;
      dev = true;
      streaming = true;
      ai = true;

      # User-level submodules stay in their namespace
      webapps = {
        enable = true;
        gmail = true;
        vscode = true;
        discord = true;
        slack = false;
      };

      hyprland = {
        defaultTerminal = "wezterm";
        defaultBrowser = "brave";
      };
    };
  };
}
```

## Key Behavioral Changes

### 1. System Features Auto-Enable Based on User Needs

In the old API, graphical environment was a system feature you explicitly enabled:

```nix
# OLD
my.features.graphical.enable = true;
```

In the new API, graphical environment is **automatically enabled** when any user has `my.users.<name>.graphical = true`:

```nix
# NEW
my.users.logger.graphical = true;  # System graphical env auto-enables
```

This simplifies configuration - you only declare what users need, not what the system provides.

### 2. Removed Options

The following options were removed (auto-detected from hardware):

- `my.features.graphical.browser.enable` → Always enabled; override per-user
- `my.features.graphical.windowManagers.hyprland` → Always enabled when graphical = true
- `my.features.development.direnv` → Moved to `my.users.<name>.apps.dev.direnv`
- `my.features.development.vscode` → Moved to `my.users.<name>.apps.dev.vscode`

### 3. New Flattened Structure

The API now follows this principle:

- **System-level**: Direct namespaces like `my.security`, `my.environment`
- **User-level**: Boolean toggles (`graphical`, `dev`) + submodules (`webapps`, `hyprland`)
- **App-level**: `my.users.<name>.apps.<category>.<app>`

## Breaking Changes Summary

### Removed

- `my.features.*` namespace entirely
- `my.users.<name>.features.*` namespace entirely

### Renamed

- `my.features.development` → `my.infra`
- `my.features.development.github-runner` → `my.infra.github-runner`
- `my.features.streaming.streamdeck` → `my.video.streamdeck`
- `my.features.streaming.v4l2loopback` → `my.video.virtual`

### New

- `my.users.<name>.graphical` (boolean)
- `my.users.<name>.dev` (boolean)
- `my.users.<name>.streaming` (boolean)
- `my.users.<name>.ai` (boolean)
- `my.video` (new namespace)
- `my.infra` (restructured namespace)

## Migration Checklist

Follow these steps to migrate your system configuration:

### Step 1: Update System-Level Options

Replace all `my.features.*` with their new counterparts:

```bash
# In your system configuration file (e.g., /etc/nixos/systems/myhost/default.nix)

# Remove:
my.features.security.enable = true;
my.features.environment.enable = true;
my.features.performance.enable = true;
my.features.ai.enable = true;

# Add:
my.security.enable = true;
my.environment.enable = true;
my.performance.enable = true;
my.ai.enable = true;
```

### Step 2: Update Graphical Configuration

Remove explicit graphical feature enablement - it auto-enables based on users:

```bash
# Remove:
my.features.graphical.enable = true;
my.features.graphical.hyprland.defaultTerminal = "wezterm";

# Moved to user config (Step 3)
```

### Step 3: Update User-Level Options

Flatten user features to top-level booleans:

```bash
# Old user config:
my.users.logger = {
  fullName = "Ido Samuelson";
  features.graphical = true;
  features.dev = true;
  features.streaming = true;
};

# New user config:
my.users.logger = {
  fullName = "Ido Samuelson";
  graphical = true;
  dev = true;
  streaming = true;
};
```

### Step 4: Move Hyprland Config

Hyprland configuration moves from features to its own namespace:

```bash
# Old:
my.features.graphical.hyprland.defaultTerminal = "wezterm";
my.features.graphical.hyprland.defaultBrowser = "brave";

# New:
my.users.logger.hyprland = {
  defaultTerminal = "wezterm";
  defaultBrowser = "brave";
};
```

### Step 5: Update Development Options

Move development-related system options to infrastructure namespace:

```bash
# Old:
my.features.development.docker.enable = true;
my.features.development.k3s.enable = true;
my.features.development.github-runner.enable = true;

# New:
my.infra = {
  docker.enable = true;
  k3s.enable = true;
  github-runner.enable = true;
};
```

### Step 6: Update Streaming/Video Options

Move streaming options to video namespace:

```bash
# Old:
my.features.streaming.streamdeck.enable = true;
my.features.streaming.v4l2loopback.enable = true;

# New:
my.video = {
  streamdeck.enable = true;
  virtual.enable = true;  # v4l2loopback
};
```

### Step 7: Rebuild and Test

After migration, test your configuration:

```bash
cd /etc/nixos

# Test configuration WITHOUT switching bootloader
sudo nixos-rebuild test --flake .#$(hostname)

# If test succeeds, apply changes
sudo nixos-rebuild switch --flake .#$(hostname)
```

## Complete Real-World Example

Here's a complete before/after for a desktop workstation (yoga):

### Before: mynixos v0.0.x

```nix
{ mynixos, ... }:

mynixos.lib.mkSystem {

  my = {
    system = {
      enable = true;
      hostname = "yoga";
    };

    hardware = {
      motherboards.gigabyte.x870e-aorus-elite-wifi7.enable = true;
    };

    filesystem = {
      type = "disko";
      config = ./disko.nix;
    };

    themes = {
      type = "stylix";
      config = ../../themes/stylix.nix;
    };

    # FEATURES NAMESPACE (DEPRECATED)
    features = {
      system.enable = true;

      environment.enable = true;
      environment.editor = pkgs.helix;

      security.enable = true;
      security.secureBoot.enable = true;
      security.yubikey.enable = true;
      security.auditRules.enable = true;

      performance.enable = true;
      performance.zramPercent = 15;

      ai.enable = true;
      ai.rocmGfxVersion = "11.0.2";

      development.docker.enable = true;
      development.k3s.enable = true;
      development.github-runner.enable = true;

      streaming.streamdeck.enable = true;

      graphical.enable = true;
      graphical.hyprland.defaultTerminal = "wezterm";
      graphical.hyprland.defaultBrowser = "brave";
    };

    users.logger = {
      fullName = "Ido Samuelson";
      email = "logger@example.com";
      hashedPassword = "<hash>";

      features.graphical = true;
      features.dev = true;
      features.streaming = true;
      features.ai = true;

      features.webapps = {
        enable = true;
        gmail = true;
        vscode = true;
        github = true;
      };

      features.hyprland = {
        defaultTerminal = "wezterm";
        leftHanded = false;
      };
    };
  };
}
```

### After: mynixos 0.1.0

```nix
{ mynixos, ... }:

mynixos.lib.mkSystem {

  my = {
    system = {
      enable = true;
      hostname = "yoga";
    };

    hardware = {
      motherboards.gigabyte.x870e-aorus-elite-wifi7.enable = true;
      cooling.nzxt.kraken-elite-rgb.elite-240-rgb.enable = true;
    };

    filesystem = {
      type = "disko";
      config = ./disko.nix;
    };

    themes = {
      type = "stylix";
      config = ../../themes/stylix.nix;
    };

    # FLATTENED NAMESPACES
    environment = {
      enable = true;
      xdg.enable = true;
      motd.enable = true;
    };

    security = {
      enable = true;
      secureBoot.enable = true;
      yubikey.enable = true;
      auditRules.enable = true;
    };

    performance = {
      enable = true;
      zramPercent = 15;
      vmtouchCache = false;
    };

    ai = {
      enable = true;
      rocmGfxVersion = "11.0.2";
    };

    infra = {
      docker.enable = true;
      k3s.enable = true;
      github-runner.enable = true;
    };

    video = {
      streamdeck.enable = true;
    };

    users.logger = {
      fullName = "Ido Samuelson";
      email = "logger@example.com";
      hashedPassword = "<hash>";

      # User features: now top-level booleans
      graphical = true;
      dev = true;
      streaming = true;
      ai = true;

      # User-level submodules
      webapps = {
        enable = true;
        gmail = true;
        vscode = true;
        github = true;
      };

      hyprland = {
        defaultTerminal = "wezterm";
        defaultBrowser = "brave";
      };
    };
  };
}
```

## Troubleshooting

### Error: "unknown option `my.features.security`"

This error means you're still using the old API. You're likely on mynixos 0.1.0+ which removed the old namespace.

**Solution**: Update your configuration using the steps above.

### Error: "conflicting definition values for `environment.systemPackages`"

This can occur if you're mixing old and new configuration formats in the same file.

**Solution**: Ensure all `my.features.*` references are updated to their new locations.

### Graphical environment doesn't enable

In the new API, graphical environment auto-enables when any user has `graphical = true`. Make sure:

```nix
my.users.logger.graphical = true;  # This auto-enables the system graphical environment
```

If Hyprland still doesn't work:

1. Check that user is actually enabled: `my.users.logger = { ... }`
2. Verify graphical flag is set to `true`
3. Check hardware has GPU support (`my.hardware.cpu`, `my.hardware.gpu`)

### AI/Ollama not starting

The AI stack was moved to system-level configuration:

```nix
my.ai = {
  enable = true;
  rocmGfxVersion = "11.0.2";  # Match your GPU
};

# Per-user MCP servers (optional):
my.users.logger.ai = {
  mcpServers.brave.enable = true;
};
```

## Commits Reference

### mynixos Repository

Key commits implementing this refactoring:

1. **3eaf5f6** - `refactor: Add flattened API namespaces alongside existing structure`
   - Added new top-level namespaces (my.security, my.environment, my.performance, etc.)
   - Added user-level boolean toggles
   - Kept old namespace for backwards compatibility

2. **e16456c** - `refactor: Update webapps and remaining modules to new API`
   - Updated app modules to use new namespaces
   - Removed old module structure

3. **972f942** - `refactor: Remove deprecated my.features namespace`
   - Deleted all my.features.* option definitions
   - Deleted all my.users.<name>.features.* option definitions
   - **Breaking change**: Old namespace no longer exists

### /etc/nixos Repository

1. **85e7b82** - `refactor: Update configs to use my.system.enable`
   - Initial migration of system configurations
   - Updated hardware references

2. **1f7bf92** - `chore: Update mynixos to use my/ directory structure`
   - Updated flake lock to new mynixos version

3. **4227b88** - `refactor: Complete mynixos API flattening from features to direct namespaces`
   - Updated yoga and skyspy-dev to use new API
   - Changed all my.features.* to direct namespaces
   - Updated user configurations

## Need Help?

If you encounter issues during migration:

1. **Check the examples**: Look at `/etc/nixos/systems/yoga/` and `/etc/nixos/systems/skyspy-dev/` for reference implementations
2. **Review this guide**: Sections above show side-by-side comparisons
3. **Check mynixos modules**: Review `/home/logger/Code/github/logger/mynixos/my/` for available options
4. **Test carefully**: Always use `sudo nixos-rebuild test` before `sudo nixos-rebuild switch`

## Summary

| Change | Old | New |
|--------|-----|-----|
| Security config | `my.features.security.enable` | `my.security.enable` |
| Environment config | `my.features.environment.enable` | `my.environment.enable` |
| Performance config | `my.features.performance.enable` | `my.performance.enable` |
| AI config | `my.features.ai.enable` | `my.ai.enable` |
| Docker config | `my.features.development.docker` | `my.infra.docker` |
| K3s config | `my.features.development.k3s` | `my.infra.k3s` |
| GitHub Runner | `my.features.development.github-runner` | `my.infra.github-runner` |
| StreamDeck | `my.features.streaming.streamdeck` | `my.video.streamdeck` |
| Virtual camera | `my.features.streaming.v4l2loopback` | `my.video.virtual` |
| User graphical | `features.graphical = true` | `graphical = true` |
| User dev | `features.dev = true` | `dev = true` |
| User streaming | `features.streaming = true` | `streaming = true` |
| User AI | `features.ai = true` | `ai = true` |
| Hyprland config | `features.hyprland.*` | `users.<name>.hyprland.*` |
| Webapps config | `features.webapps.*` | `users.<name>.webapps.*` |

Happy migrating!
