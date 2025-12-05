{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.finance.cointop {
        home.packages = with pkgs; [
          cointop
        ];
      })
      config.my.users;
  };
}
