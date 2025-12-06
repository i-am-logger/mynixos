{ config, lib, pkgs, ... }:

with lib;

{
  # Option is declared in flake.nix
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.sysinfo.neofetch {
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
        }
      )
      config.my.users;
  };
}
