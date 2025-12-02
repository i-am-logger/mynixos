{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.launchers;
in
{
  config = mkIf cfg.walker {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        walker
        wshowkeys # For screencasting - show keypresses
      ];
    }) config.my.users;
  };
}
