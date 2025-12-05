{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.dev;
in
{
  config = mkIf cfg.jq {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          jq
        ];
      })
      config.my.users;
  };
}
