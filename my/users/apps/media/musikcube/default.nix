{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.media.musikcube.enable or false) {
          home.packages = with pkgs; [
            musikcube
          ];
        })
      config.my.users;
  };
}
