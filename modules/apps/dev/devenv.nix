{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.dev;
in
{
  config = mkIf cfg.devenv {
    home-manager.users = mapAttrs
      (name: userCfg: {
        home.packages = with pkgs; [
          devenv
        ];
      })
      config.my.users;
  };
}
