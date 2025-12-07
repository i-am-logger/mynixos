{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.terminals.warp {
          home.packages = with pkgs; [
            warp-terminal
          ];
        }
      )
      config.my.users;
  };
}
