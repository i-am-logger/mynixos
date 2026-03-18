{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.terminal.viewers.feh.enable {
          home.packages = with pkgs; [
            feh
          ];

          programs.feh.enable = mkDefault true;
        })
      (activeUsers config.my.users);
  };
}
