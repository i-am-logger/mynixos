# Vogix implementation module
# Wires vogix NixOS and Home Manager modules based on my.themes.vogix configuration
{ config
, lib
, vogix
, ...
}:

with lib;

let
  cfg = config.my.themes;
  vogixCfg = cfg.vogix;
in
{
  imports = [
    vogix.nixosModules.default
  ];

  config = mkIf (cfg.enable && vogixCfg.enable) {
    # Add vogix overlay to make pkgs.vogix available
    nixpkgs.overlays = [ vogix.overlays.default ];

    # Allow vogix unfree license at NixOS level
    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "vogix"
      ];

    # Enable vogix at the NixOS level (console colors, etc.)
    vogix.enable = true;

    # Configure home-manager for each user with vogix enabled
    home-manager.users = mapAttrs
      (
        _name: userCfg:
          let
            userVogixCfg = userCfg.themes.vogix or { };
            userEnabled = userVogixCfg.enable or false;
          in
          mkIf userEnabled {
            imports = [ vogix.homeManagerModules.default ];

            # Allow vogix unfree license in home-manager context
            nixpkgs.config.allowUnfreePredicate =
              pkg:
              builtins.elem (lib.getName pkg) [
                "vogix"
              ];

            programs.vogix = {
              enable = true;
              scheme = userVogixCfg.scheme or "vogix16";
              theme = userVogixCfg.theme or "aikido";
              variant = userVogixCfg.variant or "night";
            };
          }
      )
      config.my.users;
  };
}
