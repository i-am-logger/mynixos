{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.viewers.feh {
          home.packages = with pkgs; [
            feh
          ];

          programs.feh.enable = true;
        }
      )
      config.my.users;
  };
}
