{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.communication.element.enable or false) {
          home.packages = with pkgs; [
            element-desktop
          ];
        })
      config.my.users;
  };
}
