{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf (userCfg.apps.finance.cointop.enable or false) {
          home.packages = with pkgs; [
            cointop
          ];
        })
      config.my.users;
  };
}
