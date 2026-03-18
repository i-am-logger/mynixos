{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.communication.messaging.element.enable or false {
          home.packages = with pkgs; [
            element-desktop
          ];
        })
      (activeUsers config.my.users);
  };
}
