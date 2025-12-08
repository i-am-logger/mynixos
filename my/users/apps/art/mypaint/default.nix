{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.art.mypaint.enable or false) {
          home.packages = with pkgs; [
            mypaint
          ];
        })
      config.my.users;
  };
}
