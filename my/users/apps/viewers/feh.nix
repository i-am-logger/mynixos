{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.terminal.viewers.feh.enable or false) {
          home.packages = with pkgs; [
            feh
          ];

          programs.feh.enable = mkDefault true;
        })
      config.my.users;
  };
}
