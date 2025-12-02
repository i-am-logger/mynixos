{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.visualizers.cava;
in
{
  # Option is declared in flake.nix
  config = mkIf cfg {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        cava
      ];

      # NOTE: Config file from /etc/nixos/home/cli/cava/config needs manual migration
      # Copy it to a suitable location if customization is needed
      # xdg.configFile."cava/config".source = ./config;
    }) config.my.users;
  };
}
