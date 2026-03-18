{ activeUsers, config, lib, ... }:

with lib;

let
  # Check if any user has Chromium enabled
  anyUserChromium = any
    (userCfg: userCfg.apps.graphical.browsers.chromium.enable)
    (attrValues config.my.users);
in
{
  config = mkMerge [
    # Per-user Chromium via home-manager
    {
      home-manager.users = mapAttrs
        (_name: userCfg:
          mkIf userCfg.apps.graphical.browsers.chromium.enable {
            programs.chromium = {
              enable = true;
            };
          }
        )
        (activeUsers config.my.users);
    }

    # Allow chromium unfree packages (when ANY user enables it)
    (mkIf anyUserChromium {
      my.system.allowedUnfreePackages = [
        "chromium"
        "chromium-unwrapped"
      ];
    })
  ];
}
