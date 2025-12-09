# mynixos

A NixOS-based distribution. Defaults that work, `mkDefault` so you always win.

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

- **Hardware**: Profiles for Gigabyte X870E, Lenovo Legion 16IRX8H
- **Desktop**: Hyprland + greetd
- **Security**: Secure boot (lanzaboote), YubiKey, audit rules
- **Secrets**: sops-nix integration
- **Storage**: disko, impermanence
- **Theming**: stylix
- **Dev**: Docker (rootless), direnv, binfmt
- **AI**: Ollama with ROCm

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

NixOS, home-manager, disko, impermanence, stylix, lanzaboote, sops-nix
