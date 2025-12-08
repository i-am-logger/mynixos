{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.graphical.editors.marktext.enable or false) {
          home.packages = with pkgs; [
            marktext
          ];
        })
      config.my.users;
  };
}
