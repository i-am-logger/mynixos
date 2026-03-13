{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.media.audioUtils.enable {
          home.packages = with pkgs; [
            # Audio utilities
            pavucontrol
            pamixer
          ];
        })
      config.my.users;
  };
}
