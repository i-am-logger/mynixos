{ config, lib, pkgs, ... }:

with lib;

let
  # Check if any user has Chromium enabled
  anyUserChromium = any
    (userCfg: userCfg.apps.graphical.browsers.chromium.enable or false)
    (attrValues config.my.users);
in
{
  config = mkMerge [
    # Per-user Chromium via home-manager
    {
      home-manager.users = mapAttrs
        (name: userCfg:
          mkIf (userCfg.apps.graphical.browsers.chromium.enable or false) {
            programs.chromium = {
              enable = true;
            };
          }
        )
        config.my.users;
    }

    # System-level unfree allowance (when ANY user enables it)
    (mkIf anyUserChromium {
      nixpkgs.config.allowUnfreePredicate = pkg:
        builtins.elem (pkg.pname or pkg.name or (lib.getName pkg)) [
          "chromium"
          "chromium-unwrapped"
        ];
    })
  ];
}
