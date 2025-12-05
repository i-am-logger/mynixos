{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.sync.rclone {
        home.packages = with pkgs; [
          rclone
        ];
      })
      config.my.users;
  };
}
