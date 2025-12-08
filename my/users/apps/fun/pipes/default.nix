{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.terminal.fun.pipes.enable or false) {
          home.packages = with pkgs; [
            pipes
            neo
            asciiquarium
          ];
        })
      config.my.users;
  };
}
