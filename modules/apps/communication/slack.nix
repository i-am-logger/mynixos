{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.communication;
in
{
  config = mkIf cfg.slack {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        slack
      ];
    }) config.my.users;
  };
}
