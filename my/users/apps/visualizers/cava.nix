{ config, lib, pkgs, ... }:

with lib;

{
  # Option is declared in flake.nix
  config = {
    home-manager.users = mapAttrs
      (name: userCfg:
        mkIf userCfg.apps.visualizers.cava {
          home.packages = with pkgs; [
            cava
          ];

          # NOTE: Config file from /etc/nixos/home/cli/cava/config needs manual migration
          # Copy it to a suitable location if customization is needed
          # xdg.configFile."cava/config".source = ./config;
        }
      )
      config.my.users;
  };
}
