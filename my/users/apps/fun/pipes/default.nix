{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.terminal.fun.pipes.enable {
          home.packages = with pkgs; [
            pipes
            neo
            asciiquarium
          ];
        })
      (activeUsers config.my.users);
  };
}
