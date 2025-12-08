{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.communication.slack.enable or false) {
          home.packages = with pkgs; [
            slack
          ];
        })
      config.my.users;
  };
}
