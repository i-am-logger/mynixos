{ activeUsers, config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.graphical.utils.calculator.enable {
          home.packages = with pkgs; [
            qalculate-gtk # Calculator with qalc CLI
          ];
        })
      (activeUsers config.my.users);
  };
}
