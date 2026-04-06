# Vogix implementation module
# Wires vogix NixOS and Home Manager modules based on my.theming.vogix configuration
# Also wires kanata service for behavior/modes (evdev key remapping)
{ activeUsers
, config
, lib
, vogix
, ...
}:

with lib;

let
  cfg = config.my.theming;
  vogixCfg = cfg.vogix;

in
{
  imports = [
    vogix.nixosModules.default
  ];

  config = mkIf (cfg.enable && vogixCfg.enable) {
    # Add vogix overlay to make pkgs.vogix available
    nixpkgs.overlays = [ vogix.overlays.default ];

    # Allow vogix unfree license
    my.system.allowedUnfreePackages = [ "vogix" ];

    # Enable vogix at the NixOS level (console colors, etc.)
    vogix.enable = true;

    # Configure home-manager for each user with vogix enabled
    home-manager.users = mapAttrs
      (
        _name: userCfg:
          let
            userVogixCfg = userCfg.theming.vogix or { };
            userEnabled = userVogixCfg.enable or false;
          in
          mkIf userEnabled {
            imports = [ vogix.homeManagerModules.default ];

            programs.vogix = {
              enable = true;
              appearance = {
                scheme = userVogixCfg.scheme or "vogix16";
                theme = userVogixCfg.theme or "aikido";
                variant = userVogixCfg.variant or "night";
              };
            };
          }
      )
      (activeUsers config.my.users);
  };
}
