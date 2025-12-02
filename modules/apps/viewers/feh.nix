{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.viewers;
in
{
  config = mkIf cfg.feh {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        feh
      ];

      programs.feh.enable = true;
    }) config.my.users;
  };
}
