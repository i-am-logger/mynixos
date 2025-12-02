{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.viewers.bat;
in
{
  # Option is declared in flake.nix
  config = mkIf cfg {
    home-manager.users = mapAttrs (name: userCfg: {
      programs.bat = {
        enable = true;
      };
    }) config.my.users;
  };
}
