{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.graphical.utils.imagemagick.enable or false) {
          home.packages = with pkgs; [
            imagemagick
          ];
        })
      config.my.users;
  };
}
