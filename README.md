[![CI and Release](https://github.com/i-am-logger/mynixos/actions/workflows/ci-and-release.yml/badge.svg)](https://github.com/i-am-logger/mynixos/actions/workflows/ci-and-release.yml)
[![Module Coverage](https://codecov.io/gh/i-am-logger/mynixos/graph/badge.svg)](https://codecov.io/gh/i-am-logger/mynixos)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)
[![NixOS](https://img.shields.io/badge/NixOS-5277C3?logo=nixos&logoColor=white)](https://nixos.org)
[![Release](https://img.shields.io/github/v/release/i-am-logger/mynixos)](https://github.com/i-am-logger/mynixos/releases)

# mynixos

A NixOS-based distribution. Defaults that work, `mkDefault` so you always win.

## Demo

![Hypr Vogix Demo](docs/hypr-vogix-demo.gif)

## Status

This is my personal NixOS configuration that I use daily on:
- AMD Ryzen desktop (Gigabyte X870E)
- Intel/NVIDIA laptop (Lenovo Legion 16IRX8H)

It works well for me, but it's only tested on my hardware.

## Why

Instead of copying similar configuration across machines, mynixos provides a `my.*` module API:
```nix
# Enable what you need
my.users.alice = {
  graphical.enable = true;   # Desktop environment
  dev.enable = true;         # Development tools
  terminal.enable = true;    # CLI tools
  ai.enable = true;          # Ollama, etc.
};

# Override any default
my.users.alice.environment.BROWSER = pkgs.firefox;
```

## Quick Start

### 1. Create Your Flake
```nix
# /etc/nixos/flake.nix
{
  inputs.mynixos.url = "github:i-am-logger/mynixos";

  outputs = { mynixos, ... }: {
    nixosConfigurations.myhost = mynixos.lib.mkSystem {
      my = {
        system = {
          enable = true;
          hostname = "myhost";
        };

        users.alice = {
          fullName = "Alice";
          email = "alice@example.com";
          graphical.enable = true;
          dev.enable = true;
          terminal.enable = true;
        };
      };
    };
  };
}
```

### 2. Build
```bash
nixos-rebuild switch --flake /etc/nixos#myhost
```

### 3. Override Defaults
```nix
users.alice = {
  environment.BROWSER = pkgs.firefox;
  environment.TERMINAL = pkgs.kitty;
  terminal.multiplexer = "tmux";
  graphical.webapps.slack.enable = false;
};
```

## Features

- **System**: Core config (hostname, kernel, scripts, environment)
- **Users**: 50+ apps across 28 categories, per-user config with feature bundles (graphical, dev, terminal, ai)
- **Hardware**: CPU (AMD/Intel), GPU (AMD/NVIDIA), motherboards (Gigabyte), laptops (Lenovo), cooling (NZXT), memory optimization, storage (NVMe/SATA/SSD/USB), bluetooth (Realtek), USB (HID/Thunderbolt/XHCI), peripherals (Elgato), boot (UEFI/dual-boot)
- **Desktop**: Hyprland with Waybar, Walker launcher
- **Security**: Secure boot (lanzaboote), YubiKey/SoloKey/NitroKey support, 1Password, audit rules
- **Secrets**: sops-nix integration
- **Storage**: disko partitioning, impermanence (tmpfs root + persistent storage)
- **Theming**: vogix runtime theme management
- **Dev**: Docker (rootless), direnv, devenv, binfmt, VSCode, Helix, GitHub Desktop
- **AI**: Ollama with ROCm, Claude Code, OpenCode
- **Terminals**: Ghostty, Kitty, Alacritty, WezTerm, Warp
- **Shells**: Fish, Bash with Starship prompt
- **Browsers**: Firefox, Brave, Chromium + web apps (PWAs)
- **Communication**: Signal, Slack, Element
- **Media**: Audacious, musikcube, pipewire-tools, cava visualizer
- **Infrastructure**: GitHub Actions runner, k3s
- **Performance**: zram, memory optimization, sysctl tuning
- **Streaming**: OBS-related setup
- **File Management**: Yazi, Midnight Commander, lsd, rclone sync

## Structure
```
mynixos/
  ├── flake.nix
  └── my/
      └── category/item/
          ├── options.nix
          ├── default.nix
          └── mynixos.nix
```

## Examples

See [github.com/i-am-logger/flake](https://github.com/i-am-logger/flake) for real system configurations using mynixos.

## Contributing

Contributions are always welcome. See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) or check out [my flake](https://github.com/i-am-logger/flake) to see how I use mynixos.

## License

CC BY-NC-SA 4.0 - See [LICENSE](LICENSE)

## Built On

NixOS, home-manager, disko, impermanence, vogix, lanzaboote, sops-nix, nixos-hardware
