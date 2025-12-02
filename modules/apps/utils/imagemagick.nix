{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.utils;
in
{
  config = mkIf cfg.imagemagick {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        imagemagick
      ];
    }) config.my.users;
  };
}
