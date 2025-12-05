{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.art;
in
{
  config = mkIf cfg.mypaint {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          mypaint
        ];
      })
      config.my.users;
  };
}
