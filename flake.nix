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

      # Auto-import utilities
      autoImports = import ./lib/auto-imports.nix { inherit lib; };
      
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
            ]
            # Auto-import all implementation modules from my/
            ++ (autoImports.autoImport ./my)
            # Option definitions (manual - stable list of ~17 files)
            ++ [
              (
                { ... }:
                {
                  options.my = import ./options/system.nix { inherit lib pkgs; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/security.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/environment.nix { inherit lib pkgs; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/performance.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/graphical.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/dev.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/streaming.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/ai.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/video.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/infra.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/hardware.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/presets.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/users.nix { inherit lib pkgs; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/storage.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/boot.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/filesystem.nix { inherit lib; };
                }
              )
              (
                { ... }:
                {
                  options.my = import ./options/themes.nix { inherit lib pkgs; };
                }
              )
              (import ./options/secrets.nix)
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
