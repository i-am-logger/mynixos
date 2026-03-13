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

    # Runtime theme management
    vogix = {
      url = "github:i-am-logger/vogix";
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

    # Development tooling
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , impermanence
    , lanzaboote
    , treefmt-nix
    , git-hooks
    , ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = lib.genAttrs supportedSystems;

      # mynixos library functions
      mynixosLib = import ./lib {
        inherit
          inputs
          lib
          nixpkgs
          self
          ;
      };

      # treefmt configuration (shared between formatter and checks)
      treefmtEval = forAllSystems (system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );

      # Security key type constructors (exported in lib for use in configs)
      securityKeys = {
        yubikey =
          { serialNumber
          , gpgKeyId ? null
          , ...
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
      };

      # Hardware profiles (exported in lib for use in configs)
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

    in
    {
      # Main NixOS module providing the `my.*` namespace
      nixosModules.default =
        { lib
        , pkgs
        , ...
        }:
        let
          # Use module's own pkgs when available, ensuring correct pkgs scope
          mkOptionsModule = path: args: { pkgs ? args.pkgs or null, ... }:
            { options.my = import path (args // lib.optionalAttrs (pkgs != null) { inherit pkgs; }); };
        in
        {
          config = {
            # Make helpers available to all modules
            _module.args = {
              inherit (mynixosLib) appHelpers activeUsers;
            };
          };

          imports = [
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
            ./my/system/unfree

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
            ./my/infra/github-runner
            ./my/infra/k3s

            # Storage
            ./my/storage/impermanence/aggregation.nix
            ./my/storage/impermanence/feature-aggregation.nix
            ./my/storage/impermanence/impermanence.nix

            # Users - Core
            ./my/users/defaults
            ./my/users/environment-defaults
            ./my/users/environment-validation
            ./my/users/users

            # Users - Features
            ./my/users/graphical/media
            ./my/users/terminal
            ./my/users/webapps

            # Users - Apps: AI
            ./my/users/apps/ai/opencode
            ./my/users/apps/ai/claude-code

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
            (mkOptionsModule ./my/system/options.nix { inherit lib pkgs; })
            (mkOptionsModule ./my/security/options.nix { inherit lib; })
            (mkOptionsModule ./my/environment/options.nix { inherit lib pkgs; })
            (mkOptionsModule ./my/performance/options.nix { inherit lib; })
            (mkOptionsModule ./my/graphical/options.nix { inherit lib; })
            (mkOptionsModule ./my/dev/development/options.nix { inherit lib; })
            (mkOptionsModule ./my/streaming/options.nix { inherit lib; })
            (mkOptionsModule ./my/ai/options.nix { inherit lib; })
            (mkOptionsModule ./my/video/virtual/options.nix { inherit lib; })
            (mkOptionsModule ./my/themes/options.nix { inherit lib pkgs; })

            # Category-level options
            (mkOptionsModule ./my/infra/options.nix { inherit lib; })
            (mkOptionsModule ./my/hardware/options.nix { inherit lib; })
            (mkOptionsModule ./my/hardware/boot/options.nix { inherit lib; })
            (mkOptionsModule ./my/storage/options.nix { inherit lib; })

            # Cross-cutting options
            (mkOptionsModule ./my/presets-options.nix { inherit lib; })
            (mkOptionsModule ./my/filesystem-options.nix { inherit lib; })

            # Users options
            (mkOptionsModule ./my/users/users/options.nix { inherit lib pkgs; })

            # Users opinionated defaults (mynixos.nix files)
            ./my/users/terminal/mynixos.nix
            ./my/users/graphical/mynixos.nix
            ./my/users/dev/mynixos.nix
            ./my/users/ai/mynixos.nix
            ./my/users/themes/vogix/mynixos.nix

            # Secrets (special - uses different pattern)
            (import ./my/secrets/options.nix)
          ];
        };

      # Export library functions
      lib = mynixosLib // {
        inherit securityKeys hardware;
      };

      # Formatter (treefmt: nix + shell + yaml)
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      # Checks (run via `nix flake check`)
      checks = forAllSystems (system:
        let
          moduleEvalTests = import ./tests/module-eval.nix {
            inherit lib nixpkgs system self inputs;
          };
          typeValidationTests = import ./tests/type-validation.nix {
            inherit lib nixpkgs system self inputs;
          };
        in
        {
          formatting = treefmtEval.${system}.config.build.check self;

          pre-commit = git-hooks.lib.${system}.run {
            src = self;
            hooks = {
              treefmt = {
                enable = true;
                package = treefmtEval.${system}.config.build.wrapper;
              };
              statix.enable = true;
              deadnix.enable = true;
            };
          };
        } // lib.mapAttrs' (name: value: lib.nameValuePair "module-eval-${name}" value) moduleEvalTests
        // lib.mapAttrs' (name: value: lib.nameValuePair name value) typeValidationTests
      );

      # Dev shell with pre-commit hooks installed
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (self.checks.${system}) pre-commit;
        in
        {
          default = pkgs.mkShell {
            inherit (pre-commit) shellHook;
            buildInputs = pre-commit.enabledPackages ++ [
              pkgs.statix
              pkgs.deadnix
              pkgs.shellcheck
              pkgs.shfmt
              pkgs.nixpkgs-fmt
            ];
          };
        }
      );
    };
}
