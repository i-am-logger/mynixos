{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.finance.tracking.cointop.enable or false {
          home.packages = with pkgs; [
            cointop
          ];
        })
      config.my.users;
  };
}
