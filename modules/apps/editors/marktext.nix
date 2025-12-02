{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.editors;
in
{
  config = mkIf cfg.marktext {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        marktext
      ];
    }) config.my.users;
  };
}
