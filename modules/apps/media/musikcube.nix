{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.media;
in
{
  config = mkIf cfg.musikcube {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        musikcube
      ];
    }) config.my.users;
  };
}
