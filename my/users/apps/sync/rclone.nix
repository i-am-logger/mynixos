{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.graphical.sync.rclone.enable or false) {
          home.packages = with pkgs; [
            rclone
          ];
        })
      config.my.users;
  };
}
