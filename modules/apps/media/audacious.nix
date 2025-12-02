{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.media;
in
{
  config = mkIf cfg.audacious {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        audacious
      ];
    }) config.my.users;
  };
}
