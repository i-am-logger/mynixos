{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.sync;
in
{
  config = mkIf cfg.rclone {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          rclone
        ];
      })
      config.my.users;
  };
}
