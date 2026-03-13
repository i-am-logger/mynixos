{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.dev.tools.devenv.enable or false) {
          home.packages = with pkgs; [
            devenv
          ];
        })
      config.my.users;
  };
}
