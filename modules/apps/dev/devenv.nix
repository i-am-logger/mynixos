{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.dev.devenv {
        home.packages = with pkgs; [
          devenv
        ];
      })
      config.my.users;
  };
}
