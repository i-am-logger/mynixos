{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    home-manager.users = mapAttrs
      (name: userCfg: mkIf userCfg.apps.dev.jq {
        home.packages = with pkgs; [
          jq
        ];
      })
      config.my.users;
  };
}
