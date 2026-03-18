{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.media.players.musikcube.enable or false {
          home.packages = with pkgs; [
            musikcube
          ];
        })
      (activeUsers config.my.users);
  };
}
