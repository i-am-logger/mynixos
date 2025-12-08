{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.graphical.utils.calculator.enable or false) {
          home.packages = with pkgs; [
            qalculate-gtk # Calculator with qalc CLI
          ];
        })
      config.my.users;
  };
}
