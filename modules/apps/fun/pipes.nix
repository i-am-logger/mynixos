{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.fun;
in
{
  config = mkIf cfg.pipes {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        pipes
        neo
        asciiquarium
      ];
    }) config.my.users;
  };
}
