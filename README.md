# mynixos

> A NixOS-based Linux distribution with opinionated defaults

**mynixos** is a Linux distribution built on NixOS that comes with sensible defaults for desktop and server systems. Like Ubuntu to Debian or Manjaro to Arch - opinionated but overridable.

## ⚠️ Current Status

**Personal Distribution - Field Tested on Limited Hardware**

mynixos is currently tested only on my personal systems:
- AMD Ryzen desktop (Gigabyte X870E motherboard)
- Intel/NVIDIA laptop (Lenovo Legion 16IRX8H)

Things may break. API will change. Documentation may lag behind reality. **Use at your own risk.**

This is a real, working distribution I use daily, but it's optimized for my workflow and hardware. If it works for you, great! If not, fork it and make it yours.

## Philosophy

### Opinionated, Not Rigid

mynixos has opinions:
- **Desktop**: Hyprland + Brave + Helix + Wezterm
- **Security**: Secure boot, YubiKey, audit rules
- **Development**: Docker, direnv, dev tools
- **Hardware**: Auto-detection for supported hardware

But everything uses `mkDefault` - your preferences always win.

### Type-Safe

Use typed constructors instead of strings:

```nix
yubikeys = [
  (mynixos.lib.securityKeys.yubikey {
    serialNumber = "12345678";
    gpgKeyId = "ABCD1234";
  })
];

environment.BROWSER = pkgs.brave;  # Not "brave" string
environment.EDITOR = pkgs.helix;    # Not "helix" string
```

### Structure

```
mynixos/          (the distribution)
  ├── flake.nix   (imports all modules)
  └── my/         (options + implementations co-located)
      └── category/item/
          ├── options.nix    (type definitions)
          ├── default.nix    (implementation)
          └── mynixos.nix    (opinionated defaults)

/etc/nixos/       (your config)
  ├── flake.nix   (imports mynixos)
  ├── systems/    (your machines)
  ├── users/      (your users)
  └── themes/     (your themes)
```

## Quick Start

### 1. Create Your Config

```bash
mkdir -p /etc/nixos/{systems,users,themes}
cd /etc/nixos
```

### 2. Create Flake

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
          graphical.enable = true;  # Desktop
          dev.enable = true;         # Dev tools
          terminal.enable = true;    # CLI tools
        };
      };
    };
  };
}
```

### 3. Build

```bash
nixos-rebuild switch --flake /etc/nixos#myhost
```

You get: Hyprland, Brave, Helix, Wezterm, Docker, modern CLI tools, all themed.

### 4. Override Anything

```nix
users.alice = {
  # ... other config ...
  
  environment.BROWSER = pkgs.firefox;      # Not Brave
  environment.TERMINAL = pkgs.kitty;       # Not Wezterm
  terminal.multiplexer = "tmux";           # Not zellij
  
  graphical.webapps.slack.enable = false;  # Disable specific apps
};
```

## What's Included

### Hardware Support
- Gigabyte X870E Aorus Elite WiFi7 (AMD Ryzen 9000)
- Lenovo Legion 16IRX8H (Intel 13th gen + NVIDIA RTX 4080)
- Auto-detects CPU, GPU, Bluetooth, Audio drivers

### Features
- **Desktop**: Hyprland + greetd
- **Security**: Secure boot (lanzaboote), YubiKey, audit rules
- **Secrets**: sops-nix integration
- **Storage**: disko (declarative partitioning), impermanence (tmpfs root)
- **Theming**: stylix (system-wide themes)
- **Dev**: Docker (rootless), direnv, binfmt
- **AI**: Ollama with ROCm, MCP servers
- **Streaming**: OBS, StreamDeck, virtual camera

## Configuration

### System

```nix
my.system = {
  enable = true;
  hostname = "myhost";
};
```

### Hardware

```nix
my.hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7 = {
  enable = true;
  bluetooth.enable = true;
  networking.enable = true;
  storage.nvme.enable = true;
};
```

Or for laptop:

```nix
my.hardware.laptops.lenovo.legion-16irx8h.enable = true;
```

### Security

```nix
my.security = {
  enable = true;
  secureBoot.enable = true;
  yubikey.enable = true;
};

my.secrets = {
  enable = true;
  defaultSopsFile = "${secrets}/secrets.yaml";
  ageKeyFile = "/persist/etc/sops-age-keys.txt";
};
```

### Storage

```nix
my.filesystem = {
  type = "disko";           # or "nixos"
  config = ./disko.nix;
};

my.storage.impermanence = {
  enable = true;
  useDedicatedPartition = true;
  persistUserData = true;
};
```

### Users

```nix
my.users.alice = {
  fullName = "Alice";
  email = "alice@example.com";
  shell = "bash";
  
  yubikeys = [
    (mynixos.yubikey {
      serialNumber = "12345678";
      gpgKeyId = "ABCD1234";
    })
  ];
  
  environment = {
    BROWSER = pkgs.brave;
    EDITOR = pkgs.helix;
    TERMINAL = pkgs.wezterm;
  };
  
  graphical.enable = true;
  dev.enable = true;
  ai.enable = true;
  terminal.enable = true;
};
```

## Examples

See my actual configs in `/etc/nixos` on my systems for real-world usage. They use this exact setup.

## Development

```bash
# Format code
nix fmt

# Check flake
nix flake check

# Build system
nixos-rebuild build --flake /etc/nixos#hostname
```

## Contributing

Contributions welcome! Especially:
- More hardware profiles (test on your hardware, submit profile)
- Bug fixes
- Feature improvements

Keep it simple. No grand abstractions. Just working code.

## Fork It

Want your own distribution? Fork mynixos:
1. Fork on GitHub
2. Change defaults to your preferences
3. Add your hardware profiles
4. Share it as **yournixos**

That's the point - make it yours.

## FAQ

**Is this stable?**
No. It's what I use daily, but API changes without warning. Pin to commits if you need stability.

**Will my hardware work?**
Maybe. Try it. If not, add a hardware profile and contribute it back.

**Can I use this in production?**
I do, on my personal systems. Your risk tolerance may vary.

**Why not just use vanilla NixOS?**
You should, if you want full control and don't mind writing more config. mynixos is for those who want opinionated defaults.

## License

Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)

See [LICENSE](LICENSE) file.

## Acknowledgments

Built on: NixOS, home-manager, disko, impermanence, stylix, lanzaboote, sops-nix

---

**mynixos** - NixOS with opinions
