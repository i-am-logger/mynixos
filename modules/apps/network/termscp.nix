{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.network;
in
{
  config = mkIf cfg.termscp {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          termscp
        ];
      })
      config.my.users;
  };
}
