{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.dev;
in
{
  config = mkIf cfg.githubDesktop {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          github-desktop
        ];
      })
      config.my.users;
  };
}
