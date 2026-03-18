{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.media.players.audacious.enable or false {
          home.packages = with pkgs; [
            audacious
          ];
        })
      (activeUsers config.my.users);
  };
}
