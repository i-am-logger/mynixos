{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.media;
in
{
  config = mkIf cfg.audioUtils {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        # Audio utilities
        pavucontrol
        pamixer
      ];
    }) config.my.users;
  };
}
