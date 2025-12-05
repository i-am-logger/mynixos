{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.media.audacious {
        home.packages = with pkgs; [
          audacious
        ];
      })
      config.my.users;
  };
}
