{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.dev;
in
{
  config = mkIf cfg.kdiff3 {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          kdiff3
        ];
      })
      config.my.users;
  };
}
