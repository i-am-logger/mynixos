{ inputs, lib, nixpkgs, self }:

{
  mkSystem =
    { hostname ? null
    , hardware ? [ ]
    , # List of hardware modules from mynixos.hardware.* (deprecated, use my.hardware)
      machine ? null
    , # Deprecated: use hardware instead
      users ? [ ]
    , config ? null
    , extraModules ? [ ]
    , stylix ? null
    , # Optional stylix configuration module (deprecated, use my.themes)
      my ? { }
    , # Direct mynixos configuration (my.features, my.users, my.apps, my.storage, my.themes, etc.)
    }:
    let
      # Extract filesystem configuration from my.filesystem
      filesystemType = my.filesystem.type or null;
      filesystemConfig = my.filesystem.config or null;

      # Filesystem modules based on type
      filesystemModules =
        if filesystemType == "disko" && filesystemConfig != null then [
          inputs.disko.nixosModules.disko
          {
            disko.devices = import filesystemConfig { };
          }
        ]
        else if filesystemType == "nixos" && filesystemConfig != null then [
          filesystemConfig
        ]
        else [ ];

      # Extract theme configuration from my.themes
      themeType = my.themes.type or null;
      themeConfig = my.themes.config or null;

      # Theme modules based on type
      themeModules =
        if themeType == "stylix" && themeConfig != null then [
          themeConfig
        ]
        else [ ];
    in
    lib.nixosSystem {
      specialArgs = {
        inherit inputs;
        inherit (inputs) secrets disko impermanence stylix lanzaboote self;
      };

      modules = (builtins.trace "Hardware modules: ${builtins.toString hardware}" hardware) ++ [
        # mynixos - Typed functional DSL
        self.nixosModules.default
      ]
        # Filesystem configuration (disko or nixos)
        ++ filesystemModules
        ++ (lib.optionals (machine != null) [
        # Machine hardware (deprecated approach)
        machine.path
      ])
        ++ (lib.optionals (machine != null && machine.disko != null) [
        # Disko partitioning (if machine uses it)
        inputs.disko.nixosModules.disko
        {
          disko.devices = import machine.disko { lib = nixpkgs.lib; };
        }
      ])
        ++ (lib.optionals (machine != null && machine.nixos-hardware != null) [
        # NixOS hardware module (if specified)
        inputs.nixos-hardware.nixosModules.${machine.nixos-hardware}
      ])
        ++ (lib.optionals (config != null) [
        # System-specific configuration
        config
      ])
        ++ [

        # Set hostname (supports both new my.system.hostname and deprecated my.hostname for backwards compatibility)
        {
          networking.hostName =
            if hostname != null then hostname
            else if my.system.hostname or null != null then my.system.hostname
            else if my.hostname or null != null then my.hostname
            else throw "Either hostname parameter, my.system.hostname, or my.hostname must be set";
        }

        # NixOS users
        {
          imports = map (user: user.nixosUser) users;
        }

        # Home Manager for users
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = { inherit inputs; };

          # Inject custom home-manager modules from mynixos
          # DISABLED: stylix compatibility issues
          # home-manager.sharedModules = [
          #   # Extend stylix cava module with additional gradient modes
          #   ../modules/stylix/cava-extended.nix
          # ];

          home-manager.users = lib.genAttrs
            (map (user: user.name) users)
            (name:
              let user = lib.findFirst (u: u.name == name) null users;
              in { imports = [ user.homeManager ]; }
            );
        }

        # Stylix theming module (required for extraModules to use stylix)
        # DISABLED: stylix has compatibility issues with newer nixpkgs/home-manager
        # inputs.stylix.nixosModules.stylix

        # sops-nix for secrets management
        inputs.sops-nix.nixosModules.sops
      ]
        # Theme configuration (stylix, etc.)
        ++ themeModules
        # Direct my.* configuration
        ++ (lib.optionals (my != { }) [
        { inherit my; }
      ])
        ++ extraModules;
    };
}
