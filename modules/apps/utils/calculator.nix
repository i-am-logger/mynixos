{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.utils;
in
{
  config = mkIf cfg.calculator {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          qalculate-gtk # Calculator with qalc CLI
        ];
      })
      config.my.users;
  };
}
