{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.network.termscp {
        home.packages = with pkgs; [
          termscp
        ];
      })
      config.my.users;
  };
}
