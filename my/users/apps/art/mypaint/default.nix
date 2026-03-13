{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.art.mypaint.enable {
          home.packages = with pkgs; [
            mypaint
          ];
        })
      config.my.users;
  };
}
