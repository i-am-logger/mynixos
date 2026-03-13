{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf userCfg.apps.finance.cointop.enable {
          home.packages = with pkgs; [
            cointop
          ];
        })
      config.my.users;
  };
}
