{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.dev.tools.kdiff3.enable or false) {
          home.packages = with pkgs; [
            kdiff3
          ];
        })
      config.my.users;
  };
}
