{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.communication;
in
{
  config = mkIf cfg.signal {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        signal-desktop
      ];
    }) config.my.users;
  };
}
