# mynixos

A typed functional DSL for NixOS configuration providing type-safe, composable APIs for system configuration.

## Overview

mynixos provides a strongly-typed functional interface (`my.*` namespace) for configuring NixOS systems. Instead of writing imperative NixOS modules, you use type-safe functions and get validation, composition, and maintainability.

## Quick Start

```nix
{
  inputs.mynixos.url = "github:i-am-logger/mynixos";

  outputs = { mynixos, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        mynixos.nixosModules.default
        {
          my.features.users.logger = {
            fullName = "Logger";
            email = "logger@example.com";
            packages = with pkgs; [ neofetch ];
            passkey = mynixos.yubikey {
              serialNumber = "12345678";
              gpgKeyId = "ABCD1234";
            };
          };

          my.features.security.enable = true;
          my.features.graphical.enable = true;
        }
      ];
    };
  };
}
```

## Type System

### Passkey Type Constructors

Create typed passkey configurations:

```nix
my.stacks.users.alice.passkey = yubikey {
  serialNumber = "12345678";
  gpgKeyId = "ABCD1234";
};

my.stacks.users.bob.passkey = solokey {
  serialNumber = "87654321";
};
```

### Namespace Structure

- `my.features` - Functional feature bundles
  - `users` - User configurations with packages, passkeys
  - `security` - Secure boot, yubikey, audit rules
  - `graphical` - Graphical environment (Hyprland, greetd, vscode, brave)
  - `github-runner` - GitHub Actions runners on k3s with GPU
  - `ai` - AI infrastructure (Ollama with ROCm + MCP servers)
  - `webapps` - Browser-based and Electron applications (Slack, Signal, 1Password)
  - `streaming` - Content creation tools (OBS Studio, StreamDeck, v4l2loopback)
  - `development` - Development environment (Docker, direnv, binfmt, AppImage)
  - `system` - Core system utilities (console, nix, environment, XDG)

- `my.hardware` - Hardware configuration
  - `cpu` - CPU vendor (amd/intel)
  - `gpu` - GPU vendor (amd/nvidia/intel)
  - `bluetooth`, `audio` - Component toggles

- `my.apps` - Application configurations
  - `browsers` - brave, firefox
  - `terminals` - wezterm, kitty, ghostty
  - `editors` - helix, neovim
  - `windowManagers` - hyprland

## Design Principles

1. **Type Safety** - Use type constructors, get compile-time validation
2. **Composition** - Stack multiple features cleanly
3. **Opinionated Defaults** - Sensible defaults with explicit override
4. **Separation** - Generic types here, personal data in system configs

## Architecture

mynixos provides the **type system and options**.
Your system config provides the **data** using those types.

```
mynixos/          # Generic types & implementations
  ├── flake.nix   # Type constructors & my.* options
  └── modules/    # Stack implementations

/etc/nixos/       # Personal data using mynixos types
  ├── Systems/
  │   ├── yoga/   # my.stacks.users.logger = { ... }
  │   └── dev/    # Uses same types, different data
```

## License

CC BY-NC-SA 4.0 - See LICENSE file
