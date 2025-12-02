{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.sysinfo;
in
{
  config = mkIf cfg.fastfetch {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        fastfetch
      ];
    }) config.my.users;
  };
}
