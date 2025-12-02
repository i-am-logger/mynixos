{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.apps.sysinfo.neofetch;
in
{
  # Option is declared in flake.nix
  config = mkIf cfg {
    home-manager.users = mapAttrs (name: userCfg: {
      home.packages = with pkgs; [
        neofetch
        w3m
        imagemagick
      ];

      # NOTE: Config files from /etc/nixos/home/cli/neofetch/config/ need manual migration
      # Copy them to a suitable location if customization is needed
      # xdg.configFile."neofetch/" = {
      #   source = ./config;
      #   recursive = true;
      # };
    }) config.my.users;
  };
}
