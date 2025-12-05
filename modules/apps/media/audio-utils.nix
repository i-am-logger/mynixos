{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.media.audioUtils {
        home.packages = with pkgs; [
          # Audio utilities
          pavucontrol
          pamixer
        ];
      })
      config.my.users;
  };
}
