{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.dev.githubDesktop {
        home.packages = with pkgs; [
          github-desktop
        ];
      })
      config.my.users;
  };
}
