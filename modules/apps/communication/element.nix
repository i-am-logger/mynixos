{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.communication;
in
{
  config = mkIf cfg.element {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        element-desktop
      ];
    }) config.my.users;
  };
}
