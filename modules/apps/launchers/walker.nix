{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.launchers.walker {
        home.packages = with pkgs; [
          walker
          wshowkeys # For screencasting - show keypresses
        ];
      })
      config.my.users;
  };
}
