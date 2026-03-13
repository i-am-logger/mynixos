{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.communication.signal.enable {
          home.packages = with pkgs; [
            signal-desktop
          ];
        })
      config.my.users;
  };
}
