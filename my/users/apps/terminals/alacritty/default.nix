{ activeUsers, config, lib, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.graphical.terminals.alacritty.enable {
          programs.alacritty = {
            enable = true;
          };
        })
      (activeUsers config.my.users);
  };
}
