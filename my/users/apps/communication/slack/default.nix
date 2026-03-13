{ config, lib, pkgs, ... }:

with lib;

let
  anyUserSlack = any
    (userCfg: userCfg.apps.communication.messaging.slack.enable or false)
    (attrValues config.my.users);
in
{
  config = mkMerge [
    # Allow slack unfree package (when ANY user enables it)
    (mkIf anyUserSlack {
      my.system.allowedUnfreePackages = [ "slack" ];
    })

    {
      home-manager.users = mapAttrs
        (_name: userCfg:
          mkIf (userCfg.apps.communication.messaging.slack.enable or false) {
            home.packages = with pkgs; [
              slack
            ];
          })
        config.my.users;
    }
  ];
}
