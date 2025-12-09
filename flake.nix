{
  description = "mynixos - A typed functional DSL for NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Partition management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tmpfs persistence
    impermanence = {
      url = "github:nix-community/impermanence";
    };

    # User configuration and dotfiles
    home-manager = {
      url = "github:i-am-logger/home-manager?ref=feature/webapps-module";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Themes and styling
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware configurations
    nixos-hardware = {
      url = "github:i-am-logger/nixos-hardware";
    };

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      impermanence,
      home-manager,
      stylix,
      lanzaboote,
      nixos-hardware,
      sops-nix,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;

      # mynixos library functions
      mynixosLib = import ./lib { inherit inputs lib nixpkgs self; };

      # Passkey type constructors (exported at flake level for use in configs)
      yubikey =
        {
          serialNumber,
          gpgKeyId ? null,
          ...
        }:
        {
          type = "yubikey";
          inherit serialNumber gpgKeyId;
        };

      solokey =
        { serialNumber, ... }:
        {
          type = "solokey";
          inherit serialNumber;
        };

      nitrokey =
        { serialNumber, ... }:
        {
          type = "nitrokey";
          inherit serialNumber;
        };

    in
    {
      # Export type constructors for use in system configs
      inherit yubikey solokey nitrokey;


      # Export hardware profiles (generic, anyone with this hardware can use)
      hardware = {
        motherboards = {
          gigabyte = {
            x870e-aorus-elite-wifi7 = ./my/hardware/motherboards/gigabyte/x870e-aorus-elite-wifi7;
          };
        };
        laptops = {
          lenovo = {
            legion-16irx8h = ./my/hardware/laptops/lenovo/legion-16irx8h;
          };
        };
        cooling = {
          nzxt = {
            kraken-elite-rgb = {
              elite-240-rgb = ./my/hardware/cooling/nzxt/kraken-elite-rgb/elite-240-rgb.nix;
            };
          };
        };
      };

      # Main NixOS module providing the `my.*` namespace
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.my;
        in
        {
          config = {
            # Make appHelpers available to all modules
            _module.args = {
              appHelpers = mynixosLib.appHelpers;
            };
          };

          imports =
            [
              # External modules
              impermanence.nixosModules.impermanence
              lanzaboote.nixosModules.lanzaboote

              # Implementation modules (my/)
              # Top-level features
              ./my/ai
              ./my/audio
              ./my/dev/development
              ./my/environment
              ./my/performance
              ./my/secrets
              ./my/streaming
              ./my/video/virtual

              # Graphical
              ./my/graphical
              ./my/graphical/hyprland

              # Security
              ./my/security
              ./my/security/yubikey

              # System
              ./my/system/core
              ./my/system/kernel
              ./my/system/scripts

              # Themes
              ./my/themes

              # Hardware - Bluetooth
              ./my/hardware/bluetooth/realtek

              # Hardware - Boot
              ./my/hardware/boot/dual-boot
              ./my/hardware/boot/uefi

              # Hardware - Cooling
              ./my/hardware/cooling/nzxt/kraken-elite-rgb/elite-240-rgb

              # Hardware - CPU
              ./my/hardware/cpu/amd
              ./my/hardware/cpu/intel

              # Hardware - GPU
              ./my/hardware/gpu/amd
              ./my/hardware/gpu/nvidia

              # Hardware - Laptops
              ./my/hardware/laptops/lenovo/legion-16irx8h

              # Hardware - Memory
              ./my/hardware/memory/optimization

              # Hardware - Motherboards
              ./my/hardware/motherboards/gigabyte/x870e-aorus-elite-wifi7

              # Hardware - Peripherals
              ./my/hardware/peripherals/elgato

              # Hardware - Storage
              ./my/hardware/storage/nvme
              ./my/hardware/storage/sata
              ./my/hardware/storage/ssd
              ./my/hardware/storage/usb

              # Hardware - USB
              ./my/hardware/usb/hid
              ./my/hardware/usb/thunderbolt
              ./my/hardware/usb/xhci

              # Infrastructure
              ./my/infra/github-runner/github-runner
              ./my/infra/k3s/k3s

              # Storage
              ./my/storage/impermanence/aggregation
              ./my/storage/impermanence/feature-aggregation
              ./my/storage/impermanence/impermanence

              # Users - Core
              ./my/users/defaults
              ./my/users/environment-defaults
              ./my/users/environment-validation
              ./my/users/users

              # Users - Features
              ./my/users/graphical/media
              ./my/users/terminal/terminal
              ./my/users/webapps/webapps

              # Users - Apps: AI
              ./my/users/apps/ai/opencode

              # Users - Apps: Art
              ./my/users/apps/art/mypaint

              # Users - Apps: Browsers
              ./my/users/apps/browsers/brave
              ./my/users/apps/browsers/chromium
              ./my/users/apps/browsers/firefox

              # Users - Apps: Communication
              ./my/users/apps/communication/element
              ./my/users/apps/communication/signal
              ./my/users/apps/communication/slack

              # Users - Apps: Development
              ./my/users/apps/dev/devenv
              ./my/users/apps/dev/direnv
              ./my/users/apps/dev/github-desktop
              ./my/users/apps/dev/jq
              ./my/users/apps/dev/kdiff3
              ./my/users/apps/dev/vscode

              # Users - Apps: Editors
              ./my/users/apps/editors/helix
              ./my/users/apps/editors/marktext

              # Users - Apps: File Managers
              ./my/users/apps/fileManagers/mc
              ./my/users/apps/fileManagers/yazi

              # Users - Apps: File Utils
              ./my/users/apps/fileUtils/lsd

              # Users - Apps: Finance
              ./my/users/apps/finance/cointop

              # Users - Apps: Fun
              ./my/users/apps/fun/pipes

              # Users - Apps: Git/VCS
              ./my/users/apps/git
              ./my/users/apps/jujutsu

              # Users - Apps: Launchers
              ./my/users/apps/launchers/walker

              # Users - Apps: Media
              ./my/users/apps/media/audacious
              ./my/users/apps/media/audio-utils
              ./my/users/apps/media/musikcube
              ./my/users/apps/media/pipewire-tools

              # Users - Apps: Multiplexers
              ./my/users/apps/multiplexers/tmux
              ./my/users/apps/multiplexers/zellij

              # Users - Apps: Network
              ./my/users/apps/network/termscp

              # Users - Apps: Prompts
              ./my/users/apps/prompts/starship

              # Users - Apps: Security
              ./my/users/apps/security/1password

              # Users - Apps: Shells
              ./my/users/apps/shells/bash
              ./my/users/apps/shells/fish

              # Users - Apps: SSH
              ./my/users/apps/ssh

              # Users - Apps: Status bars
              ./my/users/apps/statusbars/waybar

              # Users - Apps: Sync
              ./my/users/apps/sync/rclone

              # Users - Apps: System Info
              ./my/users/apps/sysinfo/btop
              ./my/users/apps/sysinfo/fastfetch
              ./my/users/apps/sysinfo/neofetch

              # Users - Apps: Terminals
              ./my/users/apps/terminals/alacritty
              ./my/users/apps/terminals/ghostty
              ./my/users/apps/terminals/kitty
              ./my/users/apps/terminals/warp
              ./my/users/apps/terminals/wezterm

              # Users - Apps: Utilities
              ./my/users/apps/utils/calculator
              ./my/users/apps/utils/imagemagick

              # Users - Apps: Viewers
              ./my/users/apps/viewers/bat
              ./my/users/apps/viewers/feh

              # Users - Apps: Visualizers
              ./my/users/apps/visualizers/cava

              # Users - Apps: XDG
              ./my/users/apps/xdg
            ]
            # Option definitions
            ++ [
              # Top-level options
              ({ ... }: { options.my = import ./my/system/options.nix { inherit lib pkgs; }; })
              ({ ... }: { options.my = import ./my/security/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/environment/options.nix { inherit lib pkgs; }; })
              ({ ... }: { options.my = import ./my/performance/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/graphical/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/dev/development/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/streaming/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/ai/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/video/virtual/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/themes/options.nix { inherit lib pkgs; }; })
              
              # Category-level options
              ({ ... }: { options.my = import ./my/infra/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/hardware/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/hardware/boot/options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/storage/options.nix { inherit lib; }; })
              
              # Cross-cutting options
              ({ ... }: { options.my = import ./my/presets-options.nix { inherit lib; }; })
              ({ ... }: { options.my = import ./my/filesystem-options.nix { inherit lib; }; })
              
              # Users options
              ({ ... }: { options.my = import ./my/users/users/options.nix { inherit lib pkgs; }; })
              
              # Users opinionated defaults (mynixos.nix files)
              ./my/users/terminal/mynixos.nix
              ./my/users/graphical/mynixos.nix
              ./my/users/dev/mynixos.nix
              ./my/users/ai/mynixos.nix
              
              # Secrets (special - uses different pattern)
              (import ./my/secrets/options.nix)
            ];

          config = {
            # Placeholder - actual implementations will be in separate module files
            # that import based on my.* options
          };
        };

      # Export library functions
      lib = {
        inherit yubikey solokey nitrokey;

        # System builder - the core mynixos API
        mkSystem =
          (import ./lib/mkSystem.nix {
            inherit inputs lib nixpkgs;
            self = self;
          }).mkSystem;

        # Installer ISO builder
        mkInstallerISO = (import ./lib/mkInstallerISO.nix { inherit inputs lib nixpkgs; }).mkInstallerISO;
      };

      # Formatter for nix code
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
