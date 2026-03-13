{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.communication.messaging.signal.enable or false {
          home.packages = with pkgs; [
            signal-desktop
          ];
        })
      config.my.users;
  };
}
