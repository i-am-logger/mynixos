{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.fun.pipes {
        home.packages = with pkgs; [
          pipes
          neo
          asciiquarium
        ];
      })
      config.my.users;
  };
}
