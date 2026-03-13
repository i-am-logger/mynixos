{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.art.drawing.mypaint.enable or false {
          home.packages = with pkgs; [
            mypaint
          ];
        })
      config.my.users;
  };
}
