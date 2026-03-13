{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.graphical.terminals.warp.enable {
          home.packages = with pkgs; [
            warp-terminal
          ];
        })
      config.my.users;
  };
}
