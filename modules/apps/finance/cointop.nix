{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.finance;
in
{
  config = mkIf cfg.cointop {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          cointop
        ];
      })
      config.my.users;
  };
}
