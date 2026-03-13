{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.terminal.network.termscp.enable or false) {
          home.packages = with pkgs; [
            termscp
          ];
        })
      config.my.users;
  };
}
