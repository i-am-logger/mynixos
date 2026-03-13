{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.dev.tools.githubDesktop.enable or false) {
          home.packages = with pkgs; [
            github-desktop
          ];
        })
      config.my.users;
  };
}
