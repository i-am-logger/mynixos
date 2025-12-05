{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.art.mypaint {
        home.packages = with pkgs; [
          mypaint
        ];
      })
      config.my.users;
  };
}
