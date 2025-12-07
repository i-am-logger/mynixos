{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.terminals.alacritty {
          home.packages = with pkgs; [
            alacritty
          ];

          programs.alacritty = {
            enable = true;
          };
        }
      )
      config.my.users;
  };
}
