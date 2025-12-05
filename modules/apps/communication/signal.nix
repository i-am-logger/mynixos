{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.communication.signal {
          home.packages = with pkgs; [
            signal-desktop
          ];
        }
      )
      config.my.users;
  };
}
