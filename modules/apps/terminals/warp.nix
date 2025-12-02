{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.terminals;
in
{
  config = mkIf cfg.warp {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        warp-terminal
      ];
    }) config.my.users;
  };
}
