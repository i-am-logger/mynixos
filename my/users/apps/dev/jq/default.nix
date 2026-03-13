{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (_name: userCfg:
        mkIf (userCfg.apps.dev.tools.jq.enable or false) {
          home.packages = with pkgs; [
            jq
          ];
        })
      config.my.users;
  };
}
