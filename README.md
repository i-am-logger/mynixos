[![NixOS](https://img.shields.io/badge/NixOS-5277C3?logo=nixos&logoColor=white)](https://nixos.org)
[![Release](https://img.shields.io/github/v/release/i-am-logger/mynixos)](https://github.com/i-am-logger/mynixos/releases)
[![CI and Release](https://github.com/i-am-logger/mynixos/actions/workflows/ci-and-release.yml/badge.svg)](https://github.com/i-am-logger/mynixos/actions/workflows/ci-and-release.yml)
[![Module Coverage](https://codecov.io/gh/i-am-logger/mynixos/graph/badge.svg)](https://codecov.io/gh/i-am-logger/mynixos)

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

# mynixos

NixOS and nix-darwin from one module tree. Defaults that work, `mkDefault` wherever a host should have the last word.

## Demo

![Hypr Vogix Demo](docs/hypr-vogix-demo.gif)

### vNext

<img width="3840" height="2160" alt="image" src="https://github.com/user-attachments/assets/d4571e0c-c788-4828-b69e-36feda69bc81" />

## Status

This is my personal configuration. It runs daily on:
- AMD Ryzen desktop, Gigabyte X870E — NixOS
- Intel/NVIDIA laptop, Lenovo Legion 16IRX8H — NixOS

The nix-darwin side targets a MacBook Pro M5 Max (`aarch64-darwin`); its module set
is evaluated by the test suite on every run.

It works well for me, but it's only tested on my hardware.

## Why

Instead of copying similar configuration across machines — and across operating systems — mynixos provides a `my.*` module API:
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
# flake.nix
{
  inputs.mynixos.url = "github:i-am-logger/mynixos";

  outputs = { mynixos, ... }: {
    nixosConfigurations.myhost = mynixos.lib.mkSystem {
      my = {
        system = {
          enable = true;
          hostname = "myhost";
        };

        # The hardware profile is what sets nixpkgs.hostPlatform.
        # mkSystem takes no `system` argument.
        hardware.motherboards.gigabyte.x870e-aorus-elite-wifi7.enable = true;

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

A Mac is the same call with `platform = "darwin"`:
```nix
darwinConfigurations.mymac = mynixos.lib.mkSystem {
  platform = "darwin";

  my = {
    system = {
      enable = true;
      hostname = "mymac";
    };

    hardware.laptops.apple.macbook-pro-m5-max.enable = true;

    users.alice = {
      fullName = "Alice";
      email = "alice@example.com";
      terminal.enable = true;
    };
  };

  # nix-darwin's own options, outside the `my.*` namespace.
  extraModules = [{
    system.stateVersion = 7;
    system.primaryUser = "alice";
  }];
};
```

`my` also accepts a LIST of layers. Each element becomes its own module, so the
module system merges them: lists concatenate, and two different values for one
scalar are an error rather than a silent last-wins.

### 2. Build
```bash
nixos-rebuild switch --flake .#myhost    # NixOS
darwin-rebuild switch --flake .#mymac    # macOS
```

### 3. Override Defaults
```nix
my.users.alice = {
  environment.BROWSER = pkgs.firefox;
  environment.TERMINAL = pkgs.kitty;
  terminal.multiplexer = "zellij";
  graphical.webapps.slack = false;
};
```

## Platforms

`platforms/{common,linux,darwin}.nix` compose the module set. `nixosModules.default`
imports `platforms/linux.nix`, `darwinModules.default` imports `platforms/darwin.nix`,
and both pull in `platforms/common.nix`.

Reach is structural. An option is declared in the file that implements it, and
whichever `platforms/*.nix` imports that file decides where the option exists — so
reach needs no `isLinux`/`isDarwin` guard. Setting `my.security.secureBoot` on a Mac
is `The option `my.security' does not exist` (the message names the outermost
undeclared attribute, not the leaf that was set), not a silent no-op, and the
same holds for `my.homebrew` on NixOS. `tests/user-option-reach.nix` enumerates both
option trees and fails when reach drifts from what is recorded there.

- Both platforms: `my.system`, `my.users`, `my.hardware`, `my.dev`, `my.fonts`,
  `my.network`, `my.secrets`
- NixOS only: `my.graphical`, `my.security`, `my.storage`, `my.theming`, `my.ai`,
  `my.infra`, `my.performance`, `my.streaming`, `my.forensics`, `my.environment`,
  `my.filesystem`, `my.boot`, `my.presets`, `my.video`
- macOS only: `my.homebrew`, `my.nixGc`, `my.hardware.biometrics`,
  `my.hardware.laptops.apple`, `my.network.sshFirewall`

One `mkSystem` builds both, selected by `platform ? "linux"`. It takes no `system`
argument on either: the hardware profile sets `nixpkgs.hostPlatform`, and the darwin
branch asserts the two agree. The per-user app modules write only
`home-manager.users.<name>.*`, an attribute path both platforms provide, so
`platforms/common.nix` carries one copy of them for both.

`checks` is defined for `x86_64-linux` and `aarch64-linux`, because most of `tests/`
builds a real `lib.nixosSystem`. The darwin module set is covered from those
runners: `tests/darwin-smoke.nix` and `tests/user-option-reach.nix` read only
`config` and `options`, so no `aarch64-darwin` builder is involved. `formatter`,
`devShells` and `apps` add `aarch64-darwin`.

## Features

Entries marked *(NixOS)* or *(macOS)* are declared on that platform alone — see
[Platforms](#platforms) for how reach works.

- **System**: Hostname, `rebuild-system`/`test-system`/`build-system` helpers, unfree handling, portable base CLI set; kernel selection and `system.architecture` *(NixOS)*
- **Users**: Per-user config with feature bundles (graphical, dev, terminal, ai). Apps live at `my.users.<name>.apps.<category>.<group>.<app>`, each declared by the module that implements it
- **Fonts**: `my.fonts.packages`, a Nerd Font by default
- **Hardware**: CPU (AMD/Intel), GPU (AMD/NVIDIA), motherboards (Gigabyte), laptops (Lenovo, Apple), cooling (NZXT), memory optimization, storage (NVMe/SATA/SSD/USB), bluetooth (Realtek), USB (HID/Thunderbolt/XHCI), peripherals (Elgato, Keychron), security keys (YubiKey), biometrics (Touch ID, Apple Watch), boot (UEFI/dual-boot)
- **Desktop**: Hyprland with Waybar, Walker launcher *(NixOS)*
- **Security**: Secure boot (lanzaboote), TPM2 measured boot, audit rules *(NixOS)*; 1Password
- **Secrets**: sops-nix integration
- **Storage**: disko partitioning, impermanence (tmpfs root + persistent storage) *(NixOS)*
- **Theming**: vogix runtime theme management *(NixOS)*
- **Dev**: Docker (rootless `virtualisation.docker` on NixOS, Colima on macOS), direnv, devenv, Helix, GitHub Desktop; binfmt and AppImage *(NixOS)*
- **AI**: Claude Code; Ollama with ROCm, claude-code-proxy, openclaw *(NixOS)*
- **Terminals**: Ghostty, Kitty, Alacritty, WezTerm, Warp
- **Shells**: Bash, Fish, Zsh with Starship prompt
- **Browsers**: Firefox, Brave, Chromium; `graphical.webapps` installs sites as desktop entries on NixOS
- **Communication**: Signal, Slack, Element
- **Media**: musikcube, cava visualizer; Audacious and pipewire-tools *(NixOS)*
- **Network Defense**: addrwatch, pcap, tshark, Suricata IDS, Zeek, P0F, AIDE file integrity, NetFlow/ntopng, Blocky DNS sinkhole *(NixOS)* ([docs](docs/network-defense.md))
- **Forensics**: GPU faults, kernel panics across reboot (pstore-ramoops), userspace coredumps and a retained system log, collected under `/var/log/forensics` *(NixOS)*
- **Infrastructure**: GitHub Actions runner, k3s *(NixOS)*
- **Performance**: zram compressed swap, vmtouch RAM caching, sysctl tuning *(NixOS)*
- **Streaming**: OBS Studio plus the v4l2loopback virtual camera *(NixOS)*
- **File Management**: Yazi, Midnight Commander, lsd, rclone sync
- **macOS**: Homebrew for Mac App Store apps and the casks Nix cannot package, launchd garbage collection, Touch ID for `sudo` (inside a multiplexer too, via `pam_reattach`), pointer preferences through `NSGlobalDomain`, Remote Login scoped to the tailnet with pf, CoreAudio sample-rate control

## Structure
```
mynixos/
  ├── flake.nix            # inputs, lib.mkSystem, lib.hardware, {nixos,darwin}Modules.default, checks
  ├── platforms/
  │   ├── common.nix       # modules that evaluate and mean the same on both
  │   ├── linux.nix        # NixOS      -> nixosModules.default
  │   └── darwin.nix       # nix-darwin -> darwinModules.default
  ├── lib/                 # mkSystem, mkApp, mkInstallerISO
  ├── my/
  │   └── domain/item/
  │       ├── options.nix  # declaration
  │       ├── default.nix  # implementation
  │       └── mynixos.nix  # opinionated defaults
  ├── packages/            # local derivations and patches
  └── tests/               # everything under `checks`, plus the booting VM test
```

## Examples

See [github.com/i-am-logger/flake](https://github.com/i-am-logger/flake) for real system configurations using mynixos.

## Contributing

Contributions are always welcome. See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) or check out [my flake](https://github.com/i-am-logger/flake) to see how I use mynixos.

## License

CC BY-NC-SA 4.0 - See [LICENSE](LICENSE)

## Built On

NixOS, nix-darwin, home-manager, disko, impermanence, vogix, hypr-vogix, lanzaboote, sops-nix, nix-homebrew
