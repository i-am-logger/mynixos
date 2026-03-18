{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.graphical.sync.rclone.enable {
          home.packages = with pkgs; [
            rclone
          ];
        })
      (activeUsers config.my.users);
  };
}
