{ inputs
, lib
, nixpkgs
, self
,
}:

{
  mkSystem =
    { hostname ? null
    , hardware ? [ ]
    , machine ? null
    , users ? [ ]
    , config ? null
    , extraModules ? [ ]
    , stylix ? null
    , my ? { }
    }:
    let
      # Deprecation warnings
      warnMachine = v:
        if machine != null
        then lib.warn "mkSystem: 'machine' parameter is deprecated, use 'hardware' instead" v
        else v;
      warnStylix = v:
        if stylix != null
        then lib.warn "mkSystem: 'stylix' parameter is deprecated, use 'my.theming' instead" v
        else v;
      warnMyHostname = v:
        if my.hostname or null != null
        then lib.warn "mkSystem: 'my.hostname' is deprecated, use 'my.system.hostname' or the 'hostname' parameter instead" v
        else v;

      # Extract filesystem configuration from my.filesystem
      filesystemType = my.filesystem.type or null;
      filesystemConfig = my.filesystem.config or null;

      # Filesystem modules based on type
      filesystemModules =
        if filesystemType == "disko" && filesystemConfig != null then
          [
            inputs.disko.nixosModules.disko
            {
              disko.devices = import filesystemConfig { };
            }
          ]
        else if filesystemType == "nixos" && filesystemConfig != null then
          [
            filesystemConfig
          ]
        else
          [ ];

      # Extract theme configuration from my.theming
      themeType = my.theming.type or null;
      themeConfig = my.theming.config or null;

      # Theme modules based on type
      themeModules =
        if themeType == "stylix" && themeConfig != null then
          [
            themeConfig
          ]
        else if themeConfig != null && themeType == null then
          lib.warn "mkSystem: my.theming.config is set but my.theming.type is null — theme config will be ignored" [ ]
        else
          [ ];
    in
    warnMachine (warnStylix (warnMyHostname (
      lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          inherit (inputs)
            disko
            impermanence
            stylix
            vogix
            hypr-vogix
            lanzaboote
            self
            ;
          secrets = inputs.secrets or null;
        };

        modules =
          hardware
          ++ [
            # mynixos - Typed functional DSL
            self.nixosModules.default
          ]
          # Filesystem configuration (disko or nixos)
          ++ filesystemModules
          ++ (lib.optionals (machine != null) [
            machine.path
          ])
          ++ (lib.optionals (machine != null && machine.disko != null) [
            inputs.disko.nixosModules.disko
            {
              disko.devices = import machine.disko { inherit (nixpkgs) lib; };
            }
          ])
          ++ (lib.optionals (machine != null && machine.nixos-hardware != null) [
            inputs.nixos-hardware.nixosModules.${machine.nixos-hardware}
          ])
          ++ (lib.optionals (config != null) [
            config
          ])
          ++ [

            # Set hostname
            {
              networking.hostName =
                if hostname != null then
                  hostname
                else if my.system.hostname or null != null then
                  my.system.hostname
                else if my.hostname or null != null then
                  my.hostname
                else
                  throw "Either hostname parameter, my.system.hostname, or my.hostname must be set";
            }

            # NixOS users (validate user structure)
            (
              let
                invalidUsers = lib.filter (u: !(u ? name && u ? nixosUser && u ? homeManager)) users;
              in
              assert lib.assertMsg (invalidUsers == [ ])
                "mkSystem: each user must have 'name', 'nixosUser', and 'homeManager' attributes";
              {
                imports = map (user: user.nixosUser) users;
              }
            )

            # Home Manager for users
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager = {
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = { inherit inputs; };

                users = lib.genAttrs (map (user: user.name) users) (
                  name:
                  let
                    user = lib.findFirst (u: u.name == name) null users;
                  in
                  assert lib.assertMsg (user != null) "mkSystem: user '${name}' not found in users list";
                  assert lib.assertMsg (user ? homeManager) "mkSystem: user '${name}' is missing required 'homeManager' attribute";
                  {
                    imports = [ user.homeManager ];
                  }
                );
              };
            }

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
      }
    )));
}
