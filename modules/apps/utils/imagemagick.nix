{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.utils.imagemagick {
        home.packages = with pkgs; [
          imagemagick
        ];
      })
      config.my.users;
  };
}
