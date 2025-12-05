{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.dev.kdiff3 {
        home.packages = with pkgs; [
          kdiff3
        ];
      })
      config.my.users;
  };
}
