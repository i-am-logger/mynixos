{ config, lib, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.graphical.terminals.alacritty.enable or false) {
          programs.alacritty = {
            enable = true;
          };
        })
      config.my.users;
  };
}
