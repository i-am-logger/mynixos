{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.graphical.utils.imagemagick.enable {
          home.packages = with pkgs; [
            imagemagick
          ];
        })
      (activeUsers config.my.users);
  };
}
