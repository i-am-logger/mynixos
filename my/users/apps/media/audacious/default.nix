{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.media.audacious.enable {
          home.packages = with pkgs; [
            audacious
          ];
        })
      config.my.users;
  };
}
