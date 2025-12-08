# mynixos

> A NixOS-based Linux distribution with opinionated defaults and full override capability

**mynixos** is a complete Linux distribution built on NixOS that provides a batteries-included, production-ready desktop and server environment. Like Ubuntu is to Debian or Manjaro is to Arch, mynixos is to NixOS - offering sensible defaults, integrated tooling, and a curated experience while maintaining the full power and flexibility of the underlying system.

Get a working desktop/server with minimal configuration, then customize everything to your preferences.

## Philosophy

### Opinionated, Not Rigid

mynixos comes with carefully chosen defaults:
- **Desktop**: Hyprland + greetd + opinionated app stack (Brave, Helix, Wezterm)
- **Security**: Secure boot, YubiKey support, audit rules
- **Development**: Docker, direnv, binfmt, AppImage support
- **Hardware**: Auto-detection for CPUs, GPUs, motherboards, and laptops

But **everything can be overridden** with `mkDefault` pattern - your preferences always win.

### Type-Safe Configuration

Use typed constructors instead of strings:

```nix
# Type-safe passkey configuration
yubikeys = [
  (mynixos.yubikey {
    serialNumber = "12345678";
    gpgKeyId = "ABCD1234";
  })
];

# Type-safe environment configuration
environment.BROWSER = pkgs.brave;      # Not "brave" string
environment.EDITOR = pkgs.helix;        # Not "helix" string
```

### Separation of Concerns

mynixos separates the **distribution** from your **personal configuration**:

```
mynixos/          (the distribution - this repository)
  ├── flake.nix   (distribution core, type system, defaults)
  ├── options/    (all my.* option definitions)
  └── my/         (distribution feature implementations)

/etc/nixos/       (your configuration - personal instance)
  ├── flake.nix   (imports mynixos distribution, defines systems)
  ├── systems/    (per-machine configuration)
  │   ├── desktop/
  │   └── laptop/
  ├── users/      (user definitions and preferences)
  └── themes/     (personal theming)
```

This is the same pattern as other Linux distributions:
- **Ubuntu** = Debian + opinionated defaults + integration
- **Manjaro** = Arch + opinionated defaults + ease of use
- **mynixos** = NixOS + opinionated defaults + type safety

## What Makes mynixos a Distribution?

mynixos is a **complete Linux distribution**, not just a configuration framework:

### ✅ Curated Software Stack
- Pre-selected and tested application suite
- Integrated desktop environment (Hyprland + ecosystem)
- Opinionated tool choices with justification

### ✅ Hardware Support
- Pre-configured hardware profiles (motherboards, laptops)
- Automatic driver detection and configuration
- Tested on real hardware

### ✅ Integrated Tooling
- disko (declarative partitioning)
- impermanence (stateless systems)
- stylix (system-wide theming)
- sops-nix (secrets management)
- home-manager (user environments)

### ✅ Security Defaults
- Secure boot out of the box
- YubiKey integration
- Audit rules and hardening
- Secrets management

### ✅ Release Management
- Versioned releases
- Upgrade paths
- Breaking change documentation

### ✅ Documentation & Support
- Complete user documentation
- Configuration examples
- Community support (planned)

**mynixos is to NixOS what Ubuntu is to Debian** - a user-focused, opinionated distribution built on a solid foundation.

## Quick Start

### 1. Create Your Configuration Repository

```bash
mkdir -p /etc/nixos/{systems,users,themes}
cd /etc/nixos
git init
```

### 2. Create Your Flake

```nix
# /etc/nixos/flake.nix
{
  inputs = {
    mynixos.url = "github:i-am-logger/mynixos";
  };

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
          
          # Enable features with opinionated defaults
          graphical.enable = true;  # Hyprland + apps
          dev.enable = true;         # Docker + dev tools
          terminal.enable = true;    # Terminal utilities
        };
      };
    };
  };
}
```

### 3. Build and Switch

```bash
nixos-rebuild switch --flake /etc/nixos#myhost
```

You now have:
- Hyprland window manager with greetd
- Brave browser, Helix editor, Wezterm terminal
- Docker (rootless), direnv, development tools
- Zellij multiplexer, yazi file manager, modern CLI tools
- All configured and themed consistently

### 4. Override Defaults

Don't like the defaults? Override them:

```nix
users.alice = {
  # ... other config ...
  
  # Override browser
  environment.BROWSER = pkgs.firefox;
  
  # Override terminal
  environment.TERMINAL = pkgs.kitty;
  
  # Disable specific webapps
  graphical.webapps = {
    slack.enable = false;
    signal.enable = false;
  };
  
  # Change terminal multiplexer
  terminal.multiplexer = "tmux";  # Instead of zellij default
};
```

## Features

### 🖥️ Hardware Auto-Detection

mynixos includes hardware profiles that automatically configure drivers:

**Motherboards:**
- Gigabyte X870E Aorus Elite WiFi7 (AMD Ryzen 9000 series)

**Laptops:**
- Lenovo Legion 16IRX8H (Intel 13th gen + NVIDIA RTX 4080)

**Usage:**
```nix
hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7 = {
  enable = true;
  bluetooth.enable = true;
  networking = {
    enable = true;
    useDHCP = true;
  };
  storage.nvme.enable = true;
};
```

This automatically enables:
- AMD Ryzen CPU optimizations
- AMD integrated GPU drivers
- Realtek Bluetooth
- WiFi 7 networking
- NVMe SSD optimizations

### 🔒 Security Built-In

- **Secure Boot**: lanzaboote integration for UEFI secure boot
- **YubiKey Support**: Typed passkey constructors for YubiKey, SoloKey, Nitrokey
- **Audit Rules**: Kernel syscall monitoring for compliance
- **Secrets Management**: sops-nix integration with age encryption

```nix
security = {
  enable = true;
  secureBoot.enable = true;
  yubikey.enable = true;
  auditRules.enable = true;
};

secrets = {
  enable = true;
  defaultSopsFile = "${secrets}/secrets.yaml";
  ageKeyFile = "/persist/etc/sops-age-keys.txt";
};
```

### 💾 Declarative Disk Management

mynixos integrates with **disko** for declarative partitioning and **impermanence** for tmpfs root:

```nix
filesystem = {
  type = "disko";
  config = ./disko.nix;
};

storage.impermanence = {
  enable = true;
  useDedicatedPartition = true;
  persistUserData = true;
  cloneFlakeRepo = "git@github.com:user/dotfiles.git";
  symlinkFlakeToHome = true;
};
```

Benefits:
- Fresh system on every boot (tmpfs root)
- Explicit persistence of important data
- Reproducible partitioning
- Easy system rollback

### 🎨 System-Wide Theming

mynixos integrates **stylix** for consistent theming across all applications:

```nix
themes = {
  type = "stylix";
  config = ./themes/stylix.nix;
};
```

Themes everything: terminals, editors, browsers, window managers, status bars, etc.

### 🤖 AI Infrastructure

Built-in support for local AI:

```nix
ai = {
  enable = true;
};

users.alice.ai = {
  enable = true;
  # Per-user MCP (Model Context Protocol) servers configuration
};
```

Includes:
- Ollama with ROCm support (AMD GPU acceleration)
- Model Context Protocol server integration
- Per-user AI configuration

### 🚀 Development Environment

Comprehensive development stack:

```nix
users.alice.dev = {
  enable = true;
  docker.enable = true;  # Opinionated default
};
```

Includes:
- **Docker**: Rootless containerization (auto-enabled)
- **binfmt**: Cross-platform emulation (ARM, AppImage)
- **direnv**: Per-directory environments
- **VSCode**: Per-user installation
- Development tools and utilities

### 🎥 Streaming & Content Creation

```nix
users.alice.graphical.streaming.enable = true;

hardware.peripherals.elgato.streamdeck.enable = true;

video.virtual.enable = true;  # v4l2loopback virtual camera
```

Includes:
- OBS Studio
- StreamDeck support
- Virtual camera (v4l2loopback)

### ☁️ Infrastructure Services

```nix
infra = {
  k3s.enable = true;
  
  github-runner = {
    enable = true;
    enableGpu = true;  # GPU support for runners
    repositories = [ "repo1" "repo2" ];
  };
};
```

- **k3s**: Lightweight Kubernetes
- **GitHub Actions Runners**: Self-hosted runners with GPU support

### 🛠️ Peripheral Support

```nix
hardware = {
  # Cooling
  cooling.nzxt.kraken-elite-rgb.elite-240-rgb = {
    enable = true;
    lcd.enable = true;
    rgb.enable = true;
    monitoring.enable = true;
  };
  
  # Peripherals
  peripherals.elgato.streamdeck.enable = true;
};
```

## The my.* Namespace

mynixos configuration lives in the `my.*` namespace:

### System Configuration

```nix
my.system = {
  enable = true;
  hostname = "myhost";
  kernel = pkgs.linuxPackages_latest;  # Optional override
};
```

### Hardware Configuration

```nix
my.hardware = {
  # Motherboards (auto-enables cpu, gpu, bluetooth, audio)
  motherboards.gigabyte.x870e-aorus-elite-wifi7.enable = true;
  
  # Laptops (auto-enables appropriate drivers)
  laptops.lenovo.legion-16irx8h.enable = true;
  
  # Cooling
  cooling.nzxt.kraken-elite-rgb.elite-240-rgb.enable = true;
  
  # Peripherals
  peripherals.elgato.streamdeck.enable = true;
};
```

### Boot Configuration

```nix
my.boot = {
  dualBoot.enable = true;  # Windows dual-boot support
};
```

### Environment Configuration

```nix
my.environment = {
  enable = true;
  xdg.enable = true;
  
  motd = {
    enable = true;
    content = "Welcome to mynixos!";
  };
};
```

### User Configuration

```nix
my.users.alice = {
  fullName = "Alice";
  email = "alice@example.com";
  shell = "bash";
  avatar = ./avatar.png;
  
  github = {
    username = "alice";
    repositories = [ "dotfiles" "projects" ];
  };
  
  yubikeys = [
    (mynixos.yubikey {
      serialNumber = "12345678";
      gpgKeyId = "ABCD1234";
    })
  ];
  
  # Environment variables (typed packages, not strings)
  environment = {
    BROWSER = pkgs.brave;
    EDITOR = pkgs.helix;
    TERMINAL = pkgs.wezterm;
  };
  
  # Feature flags
  graphical = {
    enable = true;
    streaming.enable = true;
    webapps.enable = true;
    media.enable = true;
  };
  
  dev = {
    enable = true;
    docker.enable = true;
  };
  
  ai.enable = true;
  
  terminal = {
    enable = true;
    multiplexer = "zellij";  # or "tmux", "screen", "none"
  };
  
  # Per-app configuration
  apps = {
    graphical.windowManagers.hyprland = {
      enable = true;
      leftHanded = true;
      sensitivity = -0.3;
    };
    
    security.passwords.onePassword.enable = true;
  };
};
```

## Configuration Examples

### Example 1: Desktop System (AMD)

```nix
# /etc/nixos/systems/desktop/default.nix
{ mynixos, secrets, ... }:

mynixos.lib.mkSystem {
  my = {
    system = {
      enable = true;
      hostname = "desktop";
    };
    
    hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7 = {
      enable = true;
      bluetooth.enable = true;
      networking.enable = true;
      storage.nvme.enable = true;
    };
    
    filesystem = {
      type = "disko";
      config = ./disko.nix;
    };
    
    themes = {
      type = "stylix";
      config = ../../themes/stylix.nix;
    };
    
    security = {
      enable = true;
      secureBoot.enable = true;
      yubikey.enable = true;
    };
    
    storage.impermanence = {
      enable = true;
      useDedicatedPartition = true;
      persistUserData = true;
    };
    
    users = import ../../users;
  };
}
```

### Example 2: Laptop System (Intel + NVIDIA)

```nix
# /etc/nixos/systems/laptop/default.nix
{ mynixos, ... }:

mynixos.lib.mkSystem {
  my = {
    system = {
      enable = true;
      hostname = "laptop";
    };
    
    hardware.laptops.lenovo.legion-16irx8h.enable = true;
    
    boot.dualBoot.enable = true;  # Windows dual-boot
    
    filesystem = {
      type = "nixos";
      config = ./filesystem.nix;
    };
    
    storage.impermanence = {
      enable = true;
      useDedicatedPartition = false;  # Use tmpfiles
    };
    
    users = import ../../users;
  };
  
  extraModules = [
    # Use specific kernel for hardware compatibility
    ({ pkgs, lib, ... }: {
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
      hardware.nvidia.open = true;
    })
  ];
}
```

### Example 3: User Definition

```nix
# /etc/nixos/users/alice/default.nix
{
  fullName = "Alice Smith";
  email = "alice@example.com";
  shell = "bash";
  avatar = ./avatar.png;
  
  github = {
    username = "alice";
    repositories = [ "dotfiles" ];
  };
  
  yubikeys = [
    (mynixos.yubikey {
      serialNumber = "12345678";
      gpgKeyId = "ABCD1234";
    })
  ];
  
  # Use mynixos opinionated defaults, override only what you want
  environment = {
    # BROWSER = pkgs.firefox;  # Uncomment to override brave default
    # EDITOR = pkgs.vim;        # Uncomment to override helix default
  };
  
  graphical = {
    enable = true;
    streaming.enable = false;  # Override: disable streaming
    media.enable = true;
  };
  
  dev.enable = true;
  ai.enable = true;
  terminal.enable = true;
}
```

## Opinionated Defaults

mynixos uses `mkDefault` for all opinions, meaning **your explicit values always win**:

### Desktop Defaults

When `graphical.enable = true`:
- **Window Manager**: Hyprland
- **Display Manager**: greetd with tuigreet
- **Browser**: Brave
- **Terminal**: Wezterm
- **Editor**: Helix
- **File Manager**: yazi
- **Multiplexer**: zellij

### Development Defaults

When `dev.enable = true`:
- **Docker**: Enabled (rootless)
- **Containerization**: Podman + Docker-compatible
- **Cross-compilation**: binfmt (ARM, AppImage)

### Terminal Defaults

When `terminal.enable = true`:
- **Multiplexer**: zellij
- **File Manager**: yazi
- **System Info**: fastfetch
- **File Viewer**: bat
- **ls replacement**: lsd

### Override Any Default

```nix
# Don't like zellij? Use tmux instead
terminal.multiplexer = "tmux";

# Don't like Brave? Use Firefox
environment.BROWSER = pkgs.firefox;

# Don't like Wezterm? Use Kitty
environment.TERMINAL = pkgs.kitty;

# Disable specific webapps
graphical.webapps = {
  slack.enable = false;
  signal.enable = false;
};
```

## Development

### Building Your System

```bash
# Check flake
nix flake check

# Build without switching
nixos-rebuild build --flake /etc/nixos#hostname

# Build and switch
nixos-rebuild switch --flake /etc/nixos#hostname

# Test in VM
nixos-rebuild build-vm --flake /etc/nixos#hostname
./result/bin/run-*-vm
```

### Testing Changes to mynixos

If you're developing mynixos itself:

```bash
cd /home/user/mynixos

# Format code
nix fmt

# Check flake
nix flake check

# Build a system using your local mynixos
nixos-rebuild build --flake /etc/nixos#hostname
```

### Project Structure

```
mynixos/
├── flake.nix           # Main flake with nixosModules.default
├── flake.lock          # Dependency versions
├── LICENSE             # CC BY-NC-SA 4.0
├── README.md           # This file
│
├── options/            # All my.* option definitions
│   ├── system.nix      # my.system options
│   ├── users.nix       # my.users options
│   ├── hardware.nix    # my.hardware options
│   ├── security.nix    # my.security options
│   ├── graphical.nix   # my.graphical (read-only flag)
│   └── ...
│
├── my/                 # Feature implementations
│   ├── system/         # System core
│   ├── users/          # User management
│   ├── hardware/       # Hardware profiles
│   │   ├── motherboards/
│   │   ├── laptops/
│   │   ├── cpu/
│   │   ├── gpu/
│   │   └── peripherals/
│   ├── security/       # Security features
│   ├── graphical/      # Graphical environment
│   ├── dev/            # Development tools
│   ├── ai/             # AI infrastructure
│   └── ...
│
├── lib/                # Library functions
│   ├── mkSystem.nix    # System builder
│   ├── app-helpers.nix # App module utilities
│   └── ...
│
└── modules/            # Legacy/compatibility modules
```

## Contributing

Contributions are welcome! Here's how to contribute:

### Adding a Hardware Profile

1. Create the profile structure:

```bash
mkdir -p my/hardware/motherboards/vendor/model/
mkdir -p my/hardware/motherboards/vendor/model/drivers/
```

2. Create `default.nix` that imports all drivers:

```nix
# my/hardware/motherboards/vendor/model/default.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.hardware.motherboards.vendor.model;
in
{
  config = mkIf cfg.enable {
    imports = [
      ./drivers/cpu.nix
      ./drivers/gpu.nix
      ./drivers/network.nix
      ./drivers/bluetooth.nix
      ./drivers/uefi-boot.nix
    ];
  };
}
```

3. Add option to `options/hardware.nix`:

```nix
hardware.motherboards.vendor.model = {
  enable = mkEnableOption "Vendor Model motherboard";
  
  bluetooth.enable = mkOption {
    type = types.bool;
    default = true;
    description = "Enable Bluetooth support";
  };
  
  # ... other options
};
```

4. Export in `flake.nix`:

```nix
hardware = {
  motherboards = {
    vendor = {
      model = ./my/hardware/motherboards/vendor/model;
    };
  };
};
```

5. Test on actual hardware and submit PR!

### Adding a Feature Module

1. Create option in `options/` directory
2. Create implementation in `my/` directory
3. Test with real configuration
4. Update README with examples
5. Submit PR

### Code Style

- Use `with lib;` at top of modules
- Prefer `mkIf` over explicit conditionals
- Use `mkMerge` for combining attribute sets
- Type all options explicitly
- Use `mkDefault` for opinionated defaults
- Keep implementations separate from options

### Testing

Before submitting:

```bash
# Format code
nix fmt

# Check flake
nix flake check

# Build a real system
nixos-rebuild build --flake /etc/nixos#testsystem

# Test in VM
nixos-rebuild build-vm --flake /etc/nixos#testsystem
```

## FAQ

### How is mynixos different from vanilla NixOS?

mynixos is a **complete Linux distribution** built on NixOS, similar to how Ubuntu builds on Debian:

**mynixos provides:**
- **Complete distribution** with curated defaults and integrated tooling
- **Opinionated defaults** - working desktop/server out of the box
- **Type-safe configuration** - typed constructors instead of strings
- **Hardware auto-detection** - motherboard/laptop profiles with driver auto-config
- **Feature modules** - high-level features instead of low-level options
- **Integrated ecosystem** - disko, impermanence, stylix, home-manager pre-configured
- **Production-ready** - security, secrets, theming configured by default

**vanilla NixOS provides:**
- Base system with minimal defaults
- Full flexibility but requires more manual configuration
- You build your own abstraction layer

Think of it like: **NixOS is Debian, mynixos is Ubuntu** (but with better reproducibility!)

### Can I use mynixos with my existing NixOS config?

Yes! mynixos is designed to be adopted incrementally. Start by migrating one feature at a time.

### What if I don't like an opinionated default?

Override it! Every default uses `mkDefault`, so your explicit configuration always wins.

### Is the API stable?

No. mynixos is pre-1.0 and the API is evolving. Breaking changes are expected and documented in release notes.

### Can I fork mynixos to create my own Linux distribution?

**Absolutely!** That's the whole point. mynixos is designed to be forked and customized:

- Fork it on GitHub
- Change the opinionated defaults to match your preferences
- Add your own hardware profiles
- Create your own flavor of NixOS-based Linux
- Share it with others under the same license

This is how Linux distributions evolve - Ubuntu forked Debian, Manjaro forked Arch, you can fork mynixos to create **yournixos**!

### How do I migrate from vanilla NixOS?

1. Keep your existing `/etc/nixos/configuration.nix`
2. Add mynixos as a flake input
3. Import `mynixos.nixosModules.default`
4. Gradually move configuration to `my.*` namespace
5. Remove old configuration as you migrate

### Does mynixos support non-AMD/Intel hardware?

Currently, hardware profiles focus on AMD/Intel CPUs and AMD/NVIDIA/Intel GPUs. ARM support is planned. Contributions welcome!

### Can I use mynixos on servers?

Yes! Disable graphical features and use server-focused features:

```nix
users.server = {
  fullName = "Server Account";
  graphical.enable = false;  # No desktop
  dev.enable = true;          # Development tools
  terminal.enable = true;     # Terminal utilities
};
```

## Roadmap

### Planned Features

- [ ] ARM hardware support (Raspberry Pi, etc.)
- [ ] More hardware profiles (AMD/Intel laptops, more motherboards)
- [ ] Installer ISO improvements
- [ ] Better documentation and examples
- [ ] NixOS module options documentation generation
- [ ] More opinionated stacks (scientific computing, gaming, etc.)

### API Stabilization

mynixos is approaching 1.0. Expected timeline:
- **0.x**: Breaking changes as needed
- **1.0**: Stable API with deprecation warnings
- **2.0+**: Major version bumps for breaking changes

## License

mynixos is licensed under **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)**.

You are free to:
- **Share**: Copy and redistribute the material
- **Adapt**: Remix, transform, and build upon the material

Under these terms:
- **Attribution**: Give appropriate credit
- **NonCommercial**: Not for commercial use
- **ShareAlike**: Distribute under the same license

See the [LICENSE](LICENSE) file for details.

## Acknowledgments

mynixos builds on the shoulders of giants:
- [NixOS](https://nixos.org/) - The foundation
- [home-manager](https://github.com/nix-community/home-manager) - User environment management
- [disko](https://github.com/nix-community/disko) - Declarative disk partitioning
- [impermanence](https://github.com/nix-community/impermanence) - Stateless systems
- [stylix](https://github.com/danth/stylix) - System-wide theming
- [lanzaboote](https://github.com/nix-community/lanzaboote) - Secure boot
- [sops-nix](https://github.com/Mic92/sops-nix) - Secrets management

---

**mynixos**: Opinionated NixOS, your way.
