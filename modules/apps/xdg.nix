{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps;
in
{
  config = mkIf cfg.xdg {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          xdg-utils
        ];

        xdg = {
          enable = true;
          mime.enable = true;
          userDirs.enable = true;
          userDirs.createDirectories = true;
        };
      })
      config.my.users;
  };
}
